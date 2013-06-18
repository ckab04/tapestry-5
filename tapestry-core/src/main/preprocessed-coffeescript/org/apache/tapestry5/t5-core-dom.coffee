# Copyright 2012-2013 The Apache Software Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# ## t5/core/dom
#
# This is the abstraction layer that allows the majority of components to operate without caring whether the
# underlying infrastructure framework is Prototype, jQuery, or something else.
#
# The abstraction layer has a number of disadvantages:
#
# * It adds a number of layers of wrapper around the infrastructure framework objects
# * It is leaky; some behaviors will vary slightly based on the active infrastructure framework
# * The abstraction is alien to both Prototype and jQuery developers; it mixes some ideas from both
# * It is much less powerful or expressive than either infrastructure framework used directly
#
# It is quite concievable that some components will require direct access to the infrastructure framework, especially
# those that are wrappers around third party libraries or plugins; however many simple components may need no more than
# the abstract layer and gain the valuable benefit of not caring about the infrastructure framework.

define ["underscore", "./utils", "./events"
#if prototype
  , "prototype"
#elseif jquery
  , "jquery"
#endif
  ],
(_, utils, events
#if jquery
  , $
#endif
  ) ->

#if prototype
  # Save a local reference to Prototype.$ ... see notes about some challenges using Prototype, jQuery,
  # and RequireJS together, here: https://github.com/jrburke/requirejs/issues/534
  $ = window.$

  # Fires a native event; something that Prototype does not normally do.
  # Returns true if the event completed normally, false if it was canceled.
  fireNativeEvent = (element, eventName) ->
    if document.createEventObject
      # IE support:
      event = document.createEventObject()
      return element.fireEvent "on#{eventName}", event

    # Everyone else:
    event = document.createEvent "HTMLEvents"
    event.initEvent eventName, true, true
    element.dispatchEvent event
    return not event.defaultPrevented

  # Currently don't want to rely on Scriptaculous, since our needs are pretty minor.
  animate = (element, styleName, initialValue, finalValue, duration, callbacks) ->
    styles = {}
    range = finalValue - initialValue
    initialTime = Date.now()
    first = true
    animator = ->
      elapsed = Date.now() - initialTime
      if elapsed >= duration
        styles[styleName] = finalValue
        element.setStyle styles
        window.clearInterval timeoutID
        triggerReflow()
        callbacks.oncomplete and callbacks.oncomplete()

      # TODO: Add an easein/easeout function

      newValue = initial + range * (elapsed / duration)

      element.setStyle styles

      if first
        callbacks.onstart and callbacks.onstart()
        first = false

    timeoutID = window.setInterval animator

    styles[styleName] = initialValue
    element.setStyle styles

  # converts a selector to an array of DOM elements
  parseSelectorToElements = (selector) ->
    if _.isString selector
      return $$ selector

    # Array is assumed to be array of DOM elements
    if _.isArray selector
      return selector

    # Assume its a single DOM element

    [selector]
#endif

  # Converts content (provided to `ElementWrapper.update()` or `append()`) into an appropriate type. This
  # primarily exists to validate the value, and to "unpack" an ElementWrapper into a DOM element.
  convertContent = (content) ->
    if _.isString content
      return content

    if _.isElement content
      return content

    if content instanceof ElementWrapper
#if jquery
      return content.$
#elseif prototype
      return content.element
#endif

    throw new Error "Provided value <#{content}> is not valid as DOM element content."

  # Generic view of an DOM event that is passed to a handler function.
  #
  # Properties:
  #
  # * nativeEvent - the native Event object, which may provide additional information.
  # * memo - the object passed to `ElementWrapper.trigger()`.
  # * type - the name of the event that was triggered.
  # * char - the character value of the pressed key, if a printable character, as a string.
  # * key -The key value of the pressed key. This is the same as the `char` property for printable keys,
  #  or a key name for others.
  class EventWrapper

#if jquery
    constructor: (event, memo) ->
      @nativeEvent = event
      @memo = memo
#elseif prototype
    constructor: (event) ->
      @nativeEvent = event
      @memo = event.memo
#endif
      # This is to satisfy YUICompressor which doesn't seem to like 'char', even
      # though it doesn't appear to be a reserved word.
      this[name] = event[name] for name in ["type", "char", "key"]

    # Stops the event which prevents further propagation of the DOM event,
    # as well as DOM event bubbling.
    stop: ->
#if jquery
      @nativeEvent.stopImmediatePropagation()
      @nativeEvent.preventDefault()
#elseif prototype
      @nativeEvent.stop()
#endif

#if jquery
  # Interface between the dom's event model, and jQuery's.
  #
  # * jqueryObject - jQuery wrapper around one or more DOM elements
  # * eventNames - space-separated list of event names
  # * match - selector to match bubbled elements, or null
  # * handler - event handler function to invoke; it will be passed an `EventWrapper` instance as the first parameter,
  #   and the memo as the second parameter. `this` will be the `ElementWrapper` for the matched element.
  #
  # Event handlers may return false to stop event propogation; this prevents an event from bubbling up, and
  # prevents any browser default behavior from triggering.  This is often easier than accepting the `EventWrapper`
  # object as the first parameter and invoking `stop()`.

  onevent = (jqueryObject, eventNames, match, handler) ->
    throw new Error "No event handler was provided." unless handler?

    wrapped = (jqueryEvent, memo) ->
      # Set `this` to be the matched ElementWrapper, rather than the element on which the event is observed
      # (which is often further up the hierarchy).
      elementWrapper = new ElementWrapper $(jqueryEvent.target)
      eventWrapper = new EventWrapper jqueryEvent, memo

      result = handler.call elementWrapper, eventWrapper, memo

      # If an event handler returns exactly false, then stop the event.
      if result is false
        eventWrapper.stop()

      return

    jqueryObject.on eventNames, match, wrapped

    return
#elseif prototype
  # Interface between the dom's event model, and Prototype's.
  #
  # * elements - array of DOM elements (or the document object)
  # * eventNames - array of event names
  # * match - selector to match bubbled elements, or null
  # * handler - event handler function to invoke; it will be passed an `EventWrapper` instance as the first parameter,
  #   and the memo as the second parameter. `this` will be the `ElementWrapper` for the matched element.
  #
  # Event handlers may return false to stop event propogation; this prevents an event from bubbling up, and
  # prevents any browser default behavior from triggering.  This is often easier than accepting the `EventWrapper`
  # object as the first parameter and invoking `stop()`.

  onevent = (elements, eventNames, match, handler) ->
      throw new Error "No event handler was provided." unless handler?

      wrapped = (prototypeEvent) ->
        # Set `this` to be the matched ElementWrapper, rather than the element on which the event is observed
        # (which is often further up the hierarchy).
        elementWrapper = new ElementWrapper prototypeEvent.findElement()
        eventWrapper = new EventWrapper prototypeEvent

        result = handler.call elementWrapper, eventWrapper, eventWrapper.memo

        # If an event handler returns exactly false, then stop the event.
        if result is false
          prototypeEvent.stop()

        return

      for element in elements
        for eventName in eventNames
          Event.on element, eventName, match, wrapped

      return
#endif

  # Wraps a DOM element, providing some common behaviors.
  # Exposes the DOM element as property `element`.
  class ElementWrapper

#if jquery
    # Passed the jQuery object
    constructor: (query) ->
      @$ = query
      @element = query[0]
#elseif prototype
    constructor: (@element) ->
#endif

    # Some coders would use some JavaScript cleverness to automate more of the mapping from the ElementWrapper API
    # to the jQuery API, but that eliminates a chance to write some very necessary documentation.

    toString: ->
      markup = @element.outerHTML

      "ElementWrapper[#{markup.substring 0, (markup.indexOf ">") + 1}]"

    # Hides the wrapped element, setting its display to 'none'.
    hide: ->
#if jquery
      @$.hide()
#elseif prototype
      @element.hide()
#endif

      triggerReflow()

      return this

    # Displays the wrapped element if hidden.
    show: ->
#if jquery
      @$.show()
#elseif prototype
      @element.show()
#endif
      triggerReflow()

      return this

    # Gets or sets a CSS property. jQuery provides a lot of mapping of names to canonical names.
    css: (name, value) ->

      if arguments.length is 1
#if jquery
        return @$.css name
#elseif prototype
        return @element.getStyle name
#endif

#if jquery
      @$.css name, value
#elseif prototype
      @element.setStyle name: value
#endif

      return this

    # Returns the offset of the object relative to the document. The returned object has
    # keys `top`' and `left`'.
    offset: ->
#if jquery
      @$.offset()
#elseif prototype
      @element.viewportOffset()
#endif

    # Removes the wrapped element from the DOM.  It can later be re-attached.
    remove: ->
#if jquery
      @$.detach()
#elseif prototype
      @element.remove()
#endif

      triggerReflow()

      return this

    # Reads or updates an attribute. With one argument, returns the current value
    # of the attribute. With two arguments, updates the attribute's value, and returns
    # the previous value. Setting an attribute to null is the same as removing it.
    #
    # Alternately, the first attribute can be an object in which case all the keys
    # and values of the object are applied as attributes, and this `ElementWrapper` is returned.
    #
    # * name - the attribute to read or update, or an object of keys and values
    # * value - (optional) the new value for the attribute
    attribute: (name, value) ->

      if _.isObject name
#if jquery
        @$.attr name
#elseif prototype
        for name, value of name
          @element.writeAttribute name, value
#endif
        return this

#if jquery
      current = @$.attr name
      if arguments.length > 1
        @$.attr name, value
#elseif prototype
      current = @element.readAttribute name
      if arguments.length > 1
        @element.writeAttribute name, value
#endif

      return current

    # Moves the cursor to the field.
    focus: ->
#if jquery
      @$.focus()
#elseif prototype
      @element.focus()
#endif

      return this

    # Returns true if the element has the indicated class name, false otherwise.
    hasClass: (name) ->
#if jquery
      @$.hasClass name
#elseif prototype
      @element.hasClassName name
#endif

    # Removes the class name from the element.
    removeClass: (name) ->
#if jquery
      @$.removeClass name
#elseif prototype
      @element.removeClassName name
#endif

      return this

    # Adds the class name to the element.
    addClass: (name) ->
#if jquery
      @$.addClass name
#elseif prototype
      @element.addClassName name
#endif

      return this

    # Updates this element with new content, replacing any old content. The new content may be HTML text, or a DOM
    # element, or an ElementWrapper, or null (to remove the body of the element).
    update: (content) ->
#if jquery
      @$.empty()

      if content
        @$.append (convertContent content)
#elseif prototype
      @element.update (content and convertContent content)
#endif

      triggerReflow()

      return this

    # Appends new content (Element, ElementWrapper, or HTML markup string) to the body of the element.
    append: (content) ->
#if jquery
      @$.append (convertContent content)
#elseif prototype
      @element.insert bottom: (convertContent content)
#endif

      triggerReflow()

      return this

    # Prepends new content (Element, ElementWrapper, or HTML markup string) to the body of the element.
    prepend: (content) ->
#if jquery
      @$.prepend (convertContent content)
#elseif prototype
      @element.insert top: (convertContent content)
#endif

      triggerReflow()

      return this

    # Inserts new content (Element, ElementWrapper, or HTML markup string) into the DOM immediately before
    # this ElementWrapper's element.
    insertBefore: (content) ->
#if jquery
      @$.before (convertContent content)
#elseif prototype
      @element.insert before: (convertContent content)
#endif

      triggerReflow()

      return this

    # Inserts new content (Element, ElementWrapper, or HTML markup string) into the DOM immediately after
    # this ElementWrapper's element.
    insertAfter: (content) ->
#if jquery
      @$.after (convertContent content)
#elseif prototype
      @element.insert after: (convertContent content)
#endif

      triggerReflow()

      return this

    # Runs an animation to fade-in the element over the specified duration.
    #
    # * duration - animation duration time, in seconds
    # * callback - function invoked after the animation is complete
    fadeIn: (duration, callback) ->
#if jquery
      @$.fadeIn duration * 1000, ->
        triggerReflow()
        callback and callback()
#elseif prototype
      animate @element, "opacity", 0, 1, duration * 1000,
        onstart: => @element.show()
        oncomplete: callback
#endif

      return this

    # Runs an animation to fade out an element over the specified duration. The element should already
    # be visible and fully opaque.
    #
    # * duration - animation duration time, in seconds
    # * callback - function invoked after the animation is complete
    fadeOut: (duration, callback) ->
#if jquery
      @$.fadeOut duration * 1000, ->
        triggerReflow()
        callback and callback()
#elseif prototype
      animate @element, "opacity", 1, 0, duration * 1000,
        oncomplete: callback
#endif

      return this

    # Finds the first child element that matches the CSS selector, wrapped as an ElementWrapper.
    # Returns null if not found.
    findFirst: (selector) ->
#if jquery
      match = @$.find selector

      if match.length
        # At least one element was matched, just keep the first
        new ElementWrapper match.first()
#elseif prototype
      match = @element.down selector

      # Prototype returns undefined if not found, we want to return null.
      if match
        new ElementWrapper match
#endif
      else
        return null

    # Finds _all_ child elements matching the CSS selector, returning them
    # as an array of ElementWrappers.
    find: (selector) ->
#if jquery
      matches = @$.find selector

      return [] if matches.length is 0

      for i in [0..(matches.length - 1)]
        new ElementWrapper matches.eq i
#elseif prototype
      matches = @element.select selector

      _.map matches, (e) -> new ElementWrapper e
#endif

    # Find the first container element that matches the selector (wrapped as an ElementWrapper),
    # or returns null.
    findParent: (selector) ->
#if jquery
      parents = @$.parents selector

      return null unless parents.length

      new ElementWrapper parents.eq(0)
#elseif prototype
      parent = @element.up selector

      return null unless parent

      new ElementWrapper parent
#endif

    # Returns this ElementWrapper if it matches the selector; otherwise, returns the first container element (as an ElementWrapper)
    # that matches the selector. Returns null if no container element matches.
    closest: (selector) ->
#if jquery
      match = @$.closest selector

      switch
        when match.length is 0 then return null
        when match[0] is @element then return this
        else return new ElementWrapper match
#elseif prototype
      if @element.match selector
        return this

      return @findParent selector
#endif

    # Returns an ElementWrapper for this element's containing element.
    # Returns null if this element has no parent (either because this element is the document object, or
    # because this element is not yet attached to the DOM).
    parent: ->
#if jquery
      parent = @$.parent()

      return null unless parent.length
#elseif prototype
      parent = @element.parentNode

      return null unless parent
#endif
      new ElementWrapper parent

    # Returns true if this element is visible, false otherwise. This does not check to see if all containers of the
    # element are visible.
    visible: ->
#if jquery
      @$.css("display") isnt "none"
#elseif prototype
      @element.visible()
#endif

    # Returns true if this element is visible, and all parent elements are also visible, up to the document body.
    deepVisible: ->
      cursor = this
      while cursor
        return false unless cursor.visible()
        cursor = cursor.parent()

        return true if cursor and cursor.element is document.body

      # Bound not reached, meaning that the Element is not currently attached to the DOM.
      return false

    # Fires a named event, passing an optional _memo_ object to event handler functions. This must support
    # common native events (exact list TBD), as well as custom events (in Prototype, custom events must have
    # a prefix that ends with a colon).
    #
    # * eventName - name of event to trigger on the wrapped Element
    # * memo - optional value assocated with the event; available as WrappedeEvent.memo in event handler functions (must
    #   be null for native events). The memo, when provided, should be an object; it is an error if it is a string or other
    #  non-object type..
    #
    # Returns true if the event fully executed, or false if the event was canceled.
    trigger: (eventName, memo) ->
      throw new Error "Attempt to trigger event with null event name" unless eventName?

      unless (_.isNull memo) or (_.isObject memo) or (_.isUndefined memo)
        throw new Error "Event memo may be null or an object, but not a simple type."

#if jquery
      jqEvent = $.Event eventName

      @$.trigger jqEvent, memo

      # Not sure if this is sufficient to ensure that event was cancelled:
      return jqEvent.isImmediatePropagationStopped()
#elseif prototype
      if (eventName.indexOf ':') > 0
        # Custom event is supported directly by Prototype:
        event = @element.fire eventName, memo
        return not event.defaultPrevented

      # Native events take some extra work:
      if memo
        throw new Error "Memo must be null when triggering a native event"

      fireNativeEvent @element, eventName
#endif

    # With no parameters, returns the current value of the element (which must be a form control element, such as `<input>` or
    # `<textarea>`). With one parameter, updates the field's value, and returns the previous value. The underlying
    # foundation is responsible for mapping this correctly based on the type of control element.
    # TODO: Define behavior for multi-named elements, such as `<select>`.
    #
    # * newValue - (optional) new value for field
    value: (newValue) ->
#if jquery
      current = @$.val()

      if arguments.length > 0
        @$.val newValue
#elseif prototype
      current = @element.getValue()

      if arguments.length > 0
        @element.setValue newValue
#endif
      return current

    # Returns true if a checkbox is checked
    checked: ->
      @element.checked

    # Stores or retrieves meta-data on the element. With one parameter, the current value for the name
    # is returned (or undefined). With two parameters, the meta-data is updated and the previous value returned.
    # For Prototype, the meta data is essentially empty (except, perhaps, for some internal keys used to store
    # event handling information).  For jQuery, the meta data may be initialized from data- attributes.
    #
    # * name - name of meta-data value to store or retrieve
    # * value - (optional) new value for meta-data
    meta: (name, value) ->
#if jquery
      current = @$.data name

      if arguments.length > 1
        @$.data name, value
#elseif prototype
      current = @element.retrieve name

      if arguments.length > 1
        @element.store name, value
#endif
      return current

    # Adds an event handler for one or more events.
    #
    # * events - one or more event names, separated by spaces
    # * match - optional: CSS expression used as a filter; only events that bubble
    #   up to the wrapped element from an originating element that matches the CSS expression
    #   will invoke the handler.
    # * handler - function invoked; the function is passed an `EventWrapper` object, and the
    #   context (`this`) is the `ElementWrapper` for the matched element.
    on: (events, match, handler) ->
      exports.on @element, events, match, handler
      return this

    # Returns the text of the element (and its children).
    text: ->
#if jquery
      @$.text()
#elseif prototype
      @element.textContent or @element.innerText
#endif

#if jquery
  # Wrapper around the `jqXHR` object
  class ResponseWrapper

    constructor: (@jqxhr, data) ->

      @status = jqxhr.status
      @statusText = jqxhr.statusText
      @json = data # Mostly right?  Need a content type check?
      @text = jqxhr.responseText

    # Retrieves a response header by name
    header: (name) ->
      @jqxhr.getResponseHeader name
#elseif prototype
  # Wrapper around the Prototype `Ajax.Response` object
  class ResponseWrapper

    constructor: (@res) ->

      @status = res.status
      @statusText = res.statusText
      @json = res.responseJSON
      @text = res.responseText

    # Retrieves a response header by name
    header: (name) ->
      @res.getHeader name
#endif


  # Performs an asynchronous Ajax request, invoking callbacks when it completes.
  #
  # This is very low level; most code will want to go through the `t5/core/ajax` module instead,
  # which adds better handling of exceptions and failures, and handles Tapestry's partial page
  # render reponse keys.
  #
  # * options.method - "post", "get", etc., default: "post".
  # * options.contentType - default "context "application/x-www-form-urlencoded"
  # * options.parameters - optional, additional key/value pairs
  # * options.success - handler to invoke on success. Passed the ResponseWrapper object.
  #   Default does nothing.
  # * options.failure - handler to invoke on failure (server responds with a non-2xx code).
  #   Passed the response. Default will throw the exception
  # * options.exception - handler to invoke when an exception occurs (often means the server is unavailable).
  #   Passed the exception. Default will generate an exception message and throw an `Error`.
  #   Note: not really supported under jQuery, a hold-over from Prototype.
  # Returns the module's exports
  ajaxRequest = (url, options = {}) ->
#if jquery
    $.ajax
      url: url
      type: options.method?.toUpperCase() or "POST"
      contentType: options.contentType
      traditional: true
      data: options.parameters
      # jQuery doesn't have the equivalent of Protoype's onException
      error: (jqXHR, textStatus, errorThrown) ->
        message = "Request to #{url} failed with status #{textStatus}"
        text = jqXHR.statusText
        if not _.isEmpty text
          message += " -- #{text}"
        message += "."

        if options.failure
          options.failure (new ResponseWrapper jqXHR), message
        else
          throw new Error message

        return

      success: (data, textStatus, jqXHR) ->

        options.success and options.success(new ResponseWrapper jqXHR, data)
        return
#elseif prototype
    finalOptions =
      method: options.method or "post"
      contentType: options.contentType or "application/x-www-form-urlencoded"
      parameters: options.parameters or {}
      onException: (ajaxRequest, exception) ->
        if options.exception
          options.exception exception
        else
          throw exception

        return

      onFailure: (response) ->
        message = "Request to #{url} failed with status #{response.getStatus()}"
        text = response.getStatusText()
        if not _.isEmpty text
          message += " -- #{text}"
        message += "."

        if options.failure
          options.failure (new ResponseWrapper response), message
        else
          throw new Error message

        return

      onSuccess: (response) ->

        # Prototype treats status == 0 as success, even though it may
        # indicate that the server didn't respond.
        if (not response.getStatus()) or (not response.request.success())
          finalOptions.onFailure(new ResponseWrapper response)
          return

        # Tapestry 5.3 includes lots more exception catching ... that just got in the way
        # of identifying the source of problems.  That's been stripped out.
        options.success and options.success(new ResponseWrapper response)
        return

    new Ajax.Request(url, finalOptions)
#endif

    return exports

  triggerReflow =
#if jquery
    _.debounce (-> $(document).trigger events.document.reflow), 250
#elseif prototype
    _.debounce (-> $(document).fire events.document.reflow), 250
#endif

  # The main export is a function that wraps a DOM element as an ElementWrapper; additional functions are attached as
  # properties.
  #
  # * element - a DOM element, or a string id of a DOM element
  #
  # Returns the ElementWrapper, or null if no element with the id exists
  exports = wrapElement = (element) ->
    if _.isString element
#if jquery
      element = document.getElementById element
#elseif prototype
      element = $ element
#endif
      return null unless element
    else
      throw new Error "Attempt to wrap a null DOM element" unless element

#if jquery
    # Assume the object is a DOM element, document or window; something that is compatible with the
    # jQuery API (especially with respect to events).
    new ElementWrapper ($ element)
#elseif prototype
    # Assume the object is a DOM element, document or window; something that is compatible with the
    # Prototype API (especially with respect to events).
    new ElementWrapper element
#endif

  _.extend exports,
    wrap: wrapElement

    triggerReflow: triggerReflow

    ajaxRequest: ajaxRequest

    # Used to add an event handler to an element (possibly from elements below it in the hierarch).
    #
    # * selector - CSS selector used to select elements to attach handler to; alternately,
    #   a single DOM element, or an array of DOM elements. The document is considered an element
    #   for these purposes.
    # * events - one or more event names, separated by spaces
    # * match - optional: CSS expression used as a filter; only events that bubble
    # * up to a selected element from an originating element that matches the CSS expression
    #   will invoke the handler.
    # * handler - function invoked; the function is passed an `EventWrapper` object, and the context (`this`)
    #   is the `ElementWrapper` for the matched element
    on: (selector, events, match, handler) ->
      unless handler?
        handler = match
        match = null

#if jquery
      elements = $ selector
#elseif prototype
      elements = parseSelectorToElements selector
      events = utils.split events
#endif
      onevent elements, events, match, handler
      return

    # onDocument() is used to add an event handler to the document object; this is used
    # for global (or default) handlers.
    onDocument: (events, match, handler) ->
      exports.on document, events, match, handler

    # Returns a wrapped version of the document.body element. Because all Tapestry JavaScript occurs
    # inside a block at the end of the document, inside the `<body`> element, it is assumed that
    # it is always safe to get the body.
    body: -> wrapElement document.body

#if jquery
  $(window).on "resize", exports.triggerReflow
#elseif prototype
  Event.observe window, "resize", triggerReflow
#endif

  return exports