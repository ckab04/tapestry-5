# Copyright 2012 The Apache Software Foundation
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

# Service Provider Interface
# This is the core of the abstraction layer that allows the majority of components to operate
# without caring whether the underlying infrastructure framework is Prototype, jQuery, or something else.
# This is the standard SPI, which wraps Prototype ... but does it in a way that makes it relatively
# easy to swap in jQuery instead.

# TODO: Define a dependency on "prototype" when that's exposed as a stub module.
define ["_"], (_) ->

  split = (str) ->
    _(str.split " ").reject (s) -> s is ""

  # Generic view of an Event that is passed to a handler function.
  #
  class Event

    constructor: (@prototypeEvent) ->

    # Stops the event which prevents further propagation of the event,
    # as well as event bubbling.
    stop: ->
      @prototypeEvent.stop()

  # Value returned from on(); an EventHandler is used to stop listening to
  # events, or even pause listening.
  class EventHandler

    # Registers the handler as an event listener for matching elements and event names.
    # elements - array of DOM elements
    # eventNames - array of event names
    # match - selector to match bubbled elements, or null
    # handler - event handler function to invoke; it will be passed an Event instance
    constructor: (elements, eventNames, match, handler) ->

      wrapped = (prototypeEvent, matchedElement) ->
        # Set "this" to be the matched element (jQuery style), rather than
        # the element on which the event is observed.
        handler.call(matchedElement, new Event prototypeEvent)

      # Prototype Event.Handler instances
      @protoHandlers = []

      _.each elements, (element) =>
        _.each eventName, (eventName) =>
          @protoHandlers.push element.on event, match, wrapped

     # Invoked after stop() to restart event listening. Returns this EventHandler instance.
     start: ->

       _.each @protoHandlers, (h) -> h.start()

       this

    # Invoked to stop or pause event listening. Returns this EventHandler instance.
    stop: ->

      _.each @protoHandlers, (h) -> h.stop()

      this

  # Wraps a DOM element, providing some common behaviors.
  # Exposes the original element as property 'element'.
  class ElementWrapper

    constructor: (element) ->

      @element = $(element)

    # Hides the wrapped element, setting its display to 'none'. Returns this ElementWrapper.
    hide: ->
      @element.hide()
      this

    # Displays the wrapped element if hidden. Returns this ElementWrapper.
    show: ->
      @element.show()
      this

    # Removes the wrapped element. Returns this ElementWrapper.
    remove: ->
      @element.remove()
      this

    # Returns the value of an attribute as a string, or null if the attribute
    # does not exist.
    getAttribute: (name) ->
      @element.readAttribute name

    # Set the value of the attribute to the given value, then returns this
    # ElementWrapper.
    # Note: Prototype has special support for values null, true, and false
    # that may not be duplicated by other implementations of the SPI.
    setAttribute: (name, value) ->
      # TODO: case where name is an object, i.e., multiple attributes in a single call.
      # Well, you can just do it, but its not guaranteed to work the same across
      # different SPIs.
      @element.writeAttribute name, value
      this

    # Returns true if the element has the indicated class name, false otherwise.
    hasClass: (name) ->
      @element.hasClassName name

    # Removes the class name from the element, then returns this ElementWrapper.
    removeClass: (name) ->
      @element.removeClassName name
      this

    # Adds the class name to the element, then returns this ElementWrapper.
    addClass: (name) ->
      @element.addClassName name
      this

    # Updates this element with new content, replacing any old content. The new content
    # may be HTML text, or a DOM element, or null (to remove the body of the element).
    # Returns this ElementWrapper.
    update: (content) ->
      @element.update content
      this

    # Returns an ElementWrapper for this element's containing element. The ElementWrapper
    # is created lazily, and cached. Returns null if this element has no parentNode (either because
    # this element is the document object, or because this element is not yet attached to the DOM).
    getContainer: ->
      unless @container
        return null unless element.parentNode
        @container = new ElementWrapper(element.parentNode)

      @container

    # Returns true if this element is visible, false otherwise. This does not check
    # to see if all containers of the element are visible.
    visible: ->
      @element.visible()

    # Fires a named event. Returns this ElementWrapper.
    trigger: (eventName) ->
      @element.fire eventName
      this

    # Adds an event handler for one or more events.
    # events - one or more event names, separated by spaces
    # match - optional: CSS expression used as a filter; only events that bubble
    # up to the wrapped element from an originating element that matches the CSS expression
    # will invoke the handler.
    # handler - function invoked; the function is passed an Event object.
    # Returns an EventHandler object, making it possible to turn event observation on or off.
    on: (events, match, handler) ->
      exports.on @element, events, match, handler

    # Searches for elements contained within this element, matching the CSS selector.
    # Returns an array of matching elements.
    find: (selector) ->
      @element.select selector

  parseSelectorToElements = (selector) ->
    if _.isString selector
      return $$ selector

    # Array is assumed to be array of DOM elements
    if _.isArray selector
      return selector

    # Assume its a single DOM element

    [selector]

  exports =

    # on() is used to add an event handler
    # selector - CSS selector used to select elements to attach handler to; alternately,
    # a single DOM element, or an array of DOM elements
    # events - one or more event names, separated by spaces
    # match - optional: CSS expression used as a filter; only events that bubble
    # up to a selected element from an originating element that matches the CSS expression
    # will invoke the handler.
    # handler - function invoked; the function is passed an Event object.
    # Returns an EventHandler object, making it possible to turn event observation on or off.
    on: (selector, events, match, handler) ->

      if handler is null
        handler = match
        match = null

      elements = parseSelectorToElements selector

      return new EventHandler(elements, split events, match, handler)

    # Returns a wrapper for the provided DOM element that includes key behaviors:
    # hide(), show(), remove(), etc.
    # element - a DOM element, or the unique id of a DOM element
    # Returns the ElementWrapper.
    wrap: (element) ->
      new ElementWrapper element