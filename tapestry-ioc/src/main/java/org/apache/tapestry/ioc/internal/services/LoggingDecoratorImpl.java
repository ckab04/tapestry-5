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

package org.apache.tapestry.ioc.internal.services;

import org.apache.tapestry.ioc.Invocation;
import org.apache.tapestry.ioc.MethodAdvice;
import org.apache.tapestry.ioc.services.AspectDecorator;
import org.apache.tapestry.ioc.services.ExceptionTracker;
import org.apache.tapestry.ioc.services.LoggingDecorator;
import org.slf4j.Logger;

public class LoggingDecoratorImpl implements LoggingDecorator
{
    private final AspectDecorator _aspectDecorator;

    private final ExceptionTracker _exceptionTracker;

    public LoggingDecoratorImpl(AspectDecorator aspectDecorator, ExceptionTracker exceptionTracker)
    {
        _aspectDecorator = aspectDecorator;
        _exceptionTracker = exceptionTracker;
    }

    public <T> T build(Class<T> serviceInterface, T delegate, String serviceId, final Logger logger)
    {
        final ServiceLogger serviceLogger = new ServiceLogger(logger, _exceptionTracker);

        MethodAdvice advice = new MethodAdvice()
        {
            public void advise(Invocation invocation)
            {
                boolean debug = logger.isDebugEnabled();

                if (debug) serviceLogger.entry(invocation);

                try
                {
                    invocation.proceed();
                }
                catch (RuntimeException ex)
                {
                    if (debug) serviceLogger.fail(invocation, ex);

                    throw ex;
                }

                if (!debug) return;

                if (invocation.isFail())
                {
                    Exception thrown = invocation.getThrown(Exception.class);

                    serviceLogger.fail(invocation, thrown);

                    return;
                }

                serviceLogger.exit(invocation);
            }
        };

        return _aspectDecorator.build(serviceInterface, delegate, advice,
                                      String.format("<Logging interceptor for %s(%s)>", serviceId,
                                                    serviceInterface.getName()));
    }

}
