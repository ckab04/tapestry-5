// Copyright 2007, 2008 The Apache Software Foundation
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

package org.apache.tapestry.services;

import org.apache.tapestry.ComponentResources;
import org.apache.tapestry.ValueEncoder;

/**
 * A source for value encoders based on a property type.
 */
public interface ValueEncoderSource
{
    /**
     * Gets or creates a value encoder based on the <em>type</em> of the named parameter.  ValueEncoders are cached based on type.
     *
     * @param parameterName the name of the parameter whose type is used to locate a {@link org.apache.tapestry.services.ValueEncoderFactory}
     * @param resources     the resources of the component, from which parameter and its type are extracted
     * @return the value encoder, or null if the type of the parameter is not known
     */
    ValueEncoder getEncoderForParameter(String parameterName, ComponentResources resources);

    /**
     * Gets or creates a value encoder for the indicated type.  ValueEncoders are cached.
     *
     * @param type type of value to be encoded and decoded
     * @return the value encoder
     */
    <T> ValueEncoder<T> getEncoderForType(Class<T> type);
}
