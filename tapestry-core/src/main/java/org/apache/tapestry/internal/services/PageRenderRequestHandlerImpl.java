// Copyright 2006, 2007, 2008 The Apache Software Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package org.apache.tapestry.internal.services;

import org.apache.tapestry.TapestryConstants;
import org.apache.tapestry.internal.structure.Page;
import org.apache.tapestry.services.ComponentEventResultProcessor;
import org.apache.tapestry.services.PageRenderRequestHandler;
import org.apache.tapestry.services.PageRenderRequestParameters;
import org.apache.tapestry.services.Traditional;

import java.io.IOException;

/**
 * Handles a PageLink as specified by a PageLinkPathSource by activating and then rendering the page.
 */
public class PageRenderRequestHandlerImpl implements PageRenderRequestHandler
{
    private final RequestPageCache _cache;

    private final ComponentEventResultProcessor _resultProcessor;

    private final PageResponseRenderer _pageResponseRenderer;

    public PageRenderRequestHandlerImpl(RequestPageCache cache,
                                        @Traditional ComponentEventResultProcessor resultProcessor,
                                        PageResponseRenderer pageResponseRenderer)
    {
        _cache = cache;
        _resultProcessor = resultProcessor;
        _pageResponseRenderer = pageResponseRenderer;
    }

    public void handle(PageRenderRequestParameters parameters) throws IOException
    {
        Page page = _cache.get(parameters.getLogicalPageName());

        ComponentResultProcessorWrapper callback = new ComponentResultProcessorWrapper(_resultProcessor);

        page.getRootElement().triggerContextEvent(TapestryConstants.ACTIVATE_EVENT, parameters.getActivationContext(),
                                                  callback);

        // The handler will have asked the result processor to send a response.

        if (callback.isAborted()) return;

        _pageResponseRenderer.renderPageResponse(page);
    }
}
