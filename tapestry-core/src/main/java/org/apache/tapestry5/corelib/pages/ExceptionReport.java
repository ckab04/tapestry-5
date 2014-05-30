// Copyright 2006-2013 The Apache Software Foundation
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

package org.apache.tapestry5.corelib.pages;

import org.apache.tapestry5.EventContext;
import org.apache.tapestry5.SymbolConstants;
import org.apache.tapestry5.alerts.AlertManager;
import org.apache.tapestry5.annotations.ContentType;
import org.apache.tapestry5.annotations.Import;
import org.apache.tapestry5.annotations.Property;
import org.apache.tapestry5.annotations.UnknownActivationContextCheck;
import org.apache.tapestry5.func.F;
import org.apache.tapestry5.func.Mapper;
import org.apache.tapestry5.internal.InternalConstants;
import org.apache.tapestry5.internal.services.PageActivationContextCollector;
import org.apache.tapestry5.internal.services.ReloadHelper;
import org.apache.tapestry5.ioc.annotations.Inject;
import org.apache.tapestry5.ioc.annotations.Symbol;
import org.apache.tapestry5.ioc.internal.util.CollectionFactory;
import org.apache.tapestry5.ioc.internal.util.InternalUtils;
import org.apache.tapestry5.services.*;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.Arrays;
import java.util.List;
import java.util.regex.Pattern;

/**
 * Responsible for reporting runtime exceptions. This page is quite verbose and is usually overridden in a production
 * application. When {@link org.apache.tapestry5.SymbolConstants#PRODUCTION_MODE} is "true", it is very abbreviated.
 *
 * @see org.apache.tapestry5.corelib.components.ExceptionDisplay
 */
@UnknownActivationContextCheck(false)
@ContentType("text/html")
@Import(stack = "core", stylesheet = "ExceptionReport.css")
public class ExceptionReport implements ExceptionReporter
{
    private static final String PATH_SEPARATOR_PROPERTY = "path.separator";

    // Match anything ending in .(something?)path.

    private static final Pattern PATH_RECOGNIZER = Pattern.compile("\\..*path$");

    @Property
    private String attributeName;

    @Inject
    @Property
    private Request request;

    @Inject
    @Symbol(SymbolConstants.PRODUCTION_MODE)
    @Property(write = false)
    private boolean productionMode;

    @Inject
    @Symbol(SymbolConstants.TAPESTRY_VERSION)
    @Property(write = false)
    private String tapestryVersion;

    @Inject
    @Symbol(SymbolConstants.APPLICATION_VERSION)
    @Property(write = false)
    private String applicationVersion;

    @Property(write = false)
    private Throwable rootException;

    @Property
    private String propertyName;

    @Property
    private String failurePage;

    @Inject
    private RequestGlobals requestGlobals;

    @Inject
    private AlertManager alertManager;

    @Inject
    private PageActivationContextCollector pageActivationContextCollector;

    @Inject
    private PageRenderLinkSource linkSource;

    @Inject
    private BaseURLSource baseURLSource;

    @Inject
    private ReloadHelper reloadHelper;

    @Inject
    private URLEncoder urlEncoder;

    @Property
    private String rootURL;

    @Property
    private ThreadInfo thread;

    public class ThreadInfo implements Comparable<ThreadInfo>
    {
        public final String className, name, flags;

        public final ThreadGroup group;

        public ThreadInfo(String className, String name, String flags, ThreadGroup group)
        {
            this.className = className;
            this.name = name;
            this.flags = flags;
            this.group = group;
        }

        @Override
        public int compareTo(ThreadInfo o)
        {
            return name.compareTo(o.name);
        }
    }

    private final String pathSeparator = System.getProperty(PATH_SEPARATOR_PROPERTY);

    public boolean isShowActions()
    {
        return failurePage != null && !request.isXHR();
    }

    public void reportException(Throwable exception)
    {
        rootException = exception;

        failurePage = (request.getAttribute(InternalConstants.ACTIVE_PAGE_LOADED) == null)
                ? null
                : requestGlobals.getActivePageName();

        rootURL = baseURLSource.getBaseURL(request.isSecure());
    }

    public Object[] getReloadContext()
    {
        return pageActivationContextCollector.collectPageActivationContext(failurePage);
    }

    Object onActionFromReloadFirst(EventContext reloadContext)
    {
        reloadHelper.forceReload();

        return linkSource.createPageRenderLinkWithContext(urlEncoder.decode(request.getParameter("loadPage")), reloadContext);
    }

    Object onActionFromReloadRoot() throws MalformedURLException
    {
        reloadHelper.forceReload();

        return new URL(baseURLSource.getBaseURL(request.isSecure()));
    }


    public boolean getHasSession()
    {
        return request.getSession(false) != null;
    }

    public Session getSession()
    {
        return request.getSession(false);
    }

    public Object getAttributeValue()
    {
        return getSession().getAttribute(attributeName);
    }

    /**
     * Returns a <em>sorted</em> list of system property names.
     */
    public List<String> getSystemProperties()
    {
        return InternalUtils.sortedKeys(System.getProperties());
    }

    public String getPropertyValue()
    {
        return System.getProperty(propertyName);
    }

    public boolean isComplexProperty()
    {
        return PATH_RECOGNIZER.matcher(propertyName).find() && getPropertyValue().contains(pathSeparator);
    }

    public String[] getComplexPropertyValue()
    {
        // Neither : nor ; is a regexp character.

        return getPropertyValue().split(pathSeparator);
    }

    private Thread[] assembleThreads()
    {
        ThreadGroup rootGroup = Thread.currentThread().getThreadGroup();

        while (true)
        {
            ThreadGroup parentGroup = rootGroup.getParent();
            if (parentGroup == null)
            {
                break;
            }
            rootGroup = parentGroup;
        }

        Thread[] threads = new Thread[rootGroup.activeCount()];

        while (true)
        {
            // A really ugly API. threads.length must be larger than
            // the actual number of threads, just so we can determine
            // if we're done.
            int count = rootGroup.enumerate(threads, true);
            if (count < threads.length)
            {
                return Arrays.copyOf(threads, count);
            }
            threads = new Thread[threads.length * 2];
        }
    }

    public List<ThreadInfo> getThreads()
    {
        return F.flow(assembleThreads()).map(new Mapper<Thread, ThreadInfo>()
        {
            @Override
            public ThreadInfo map(Thread t)
            {
                List<String> flags = CollectionFactory.newList();

                if (t.isDaemon())
                {
                    flags.add("daemon");
                }
                if (!t.isAlive())
                {
                    flags.add("NOT alive");
                }
                if (t.isInterrupted())
                {
                    flags.add("interrupted");
                }

                if (t.getPriority() != Thread.NORM_PRIORITY)
                {
                    flags.add("priority " + t.getPriority());
                }

                return new ThreadInfo(Thread.currentThread() == t ? "active-thread" : "",
                        t.getName(),
                        InternalUtils.join(flags),
                        t.getThreadGroup());
            }
        }).sort().toList();
    }
}
