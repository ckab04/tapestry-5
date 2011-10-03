// Copyright 2006, 2009, 2011 The Apache Software Foundation
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

package org.apache.tapestry5.internal.parser;

import org.apache.tapestry5.MarkupWriter;
import org.apache.tapestry5.ioc.Location;
import org.apache.tapestry5.runtime.RenderCommand;
import org.apache.tapestry5.runtime.RenderQueue;

/**
 * The start of an ordinary element within the template (as opposed to {@link org.apache.tapestry5.internal.parser.StartComponentToken},
 * which represents an active Tapestry token. A start element token may be immediately followed by {@link
 * org.apache.tapestry5.internal.parser.AttributeToken}s that represents the attributes associated with the element. A
 * start element token will always be balanced by a {@link org.apache.tapestry5.internal.parser.EndElementToken} (though
 * there will likely be some amount of intermediate tokens).
 */
public class StartElementToken extends TemplateToken implements RenderCommand
{
    public final String namespaceURI;

    public final String name;

    public StartElementToken(String namespaceURI, String name, Location location)
    {
        super(TokenType.START_ELEMENT, location);

        this.namespaceURI = namespaceURI;
        this.name = name;
    }

    @Override
    public String toString()
    {
        StringBuilder builder = new StringBuilder("Start[");

        if (namespaceURI != null && namespaceURI.length() > 0) builder.append(namespaceURI).append(" ");

        builder.append(name).append("]");

        return builder.toString();
    }

    public void render(MarkupWriter writer, RenderQueue queue)
    {
        writer.elementNS(namespaceURI, name);
    }
}
