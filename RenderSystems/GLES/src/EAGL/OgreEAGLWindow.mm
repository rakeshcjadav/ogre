/*
-----------------------------------------------------------------------------
This source file is part of OGRE
    (Object-oriented Graphics Rendering Engine)
For the latest info, see http://www.ogre3d.org/

Copyright (c) 2000-2009 Torus Knot Software Ltd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
--------------------------------------------------------------------------*/

#include "OgreEAGLWindow.h"

#include "OgreEAGLView.h"
#include "OgreEAGLViewController.h"
#include "OgreEAGLSupport.h"
#include "OgreEAGLESContext.h"

#include "OgreRoot.h"
#include "OgreWindowEventUtilities.h"

#include "OgreGLESPixelFormat.h"

namespace Ogre {
    EAGLWindow::EAGLWindow(EAGLSupport *glsupport)
        :   mClosed(false),
            mVisible(false),
            mIsExternal(false),
            mUsingExternalView(false),
            mUsingExternalViewController(false),
            mIsContentScalingSupported(false),
            mContentScalingFactor(1.0),
            mCurrentOSVersion(0.0),
            mGLSupport(glsupport),
            mContext(NULL),
            mWindow(nil),
            mView(nil),
            mViewController(nil)
    {
        mIsFullScreen = true;
        mActive = true;
        mHwGamma = false;

        // Check for content scaling.  iOS 4 or later
        mCurrentOSVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
        if(mCurrentOSVersion >= 4.0)
            mIsContentScalingSupported = true;
    }

    EAGLWindow::~EAGLWindow()
    {
        destroy();

        if (mContext == NULL)
        {
            OGRE_DELETE mContext;
        }

        mContext = NULL;
    }

    void EAGLWindow::destroy(void)
    {
        if (mClosed)
        {
            return;
        }

        mClosed = true;
        mActive = false;

        if (!mIsExternal)
        {
            WindowEventUtilities::_removeRenderWindow(this);

            [mWindow release];
            mWindow = nil;
        }

        if (mIsFullScreen)
        {
            switchFullScreen(false);
        }
        
        if(!mUsingExternalView)
            [mView release];

        if(!mUsingExternalViewController)
            [mViewController release];
    }

    void EAGLWindow::setFullscreen(bool fullscreen, uint width, uint height)
    {
    }

    void EAGLWindow::reposition(int left, int top)
	{
	}
    
	void EAGLWindow::resize(unsigned int width, unsigned int height)
	{
        if(!mWindow) return;

        // Check if the window size really changed
        if(mWidth == width && mHeight == height)
            return;

        // Destroy and recreate the framebuffer with new dimensions 
        mContext->destroyFramebuffer();

        mWidth = width * mContentScalingFactor;
        mHeight = height * mContentScalingFactor;

        mContext->createFramebuffer();

        for (ViewportList::iterator it = mViewportList.begin(); it != mViewportList.end(); ++it)
        {
            (*it).second->_updateDimensions();
        }
	}

	void EAGLWindow::windowMovedOrResized()
	{
		CGRect frame = [mView frame];
		mWidth = (unsigned int)frame.size.width;
		mHeight = (unsigned int)frame.size.height;
        mLeft = (int)frame.origin.x;
        mTop = (int)frame.origin.y+(int)frame.size.height;

        for (ViewportList::iterator it = mViewportList.begin(); it != mViewportList.end(); ++it)
        {
            (*it).second->_updateDimensions();
        }
	}

    void EAGLWindow::_beginUpdate(void)
    {
        // Call the base class method first
        RenderTarget::_beginUpdate();

#if __IPHONE_4_0
        if(mCurrentOSVersion >= 4.0)
        {
            if(mContext->mIsMultiSampleSupported && mContext->mNumSamples > 0)
            {
                // Bind the FSAA buffer if we're doing multisampling
                glBindFramebufferOES(GL_FRAMEBUFFER_OES, mContext->mFSAAFramebuffer);
                GL_CHECK_ERROR
            }
        }
#endif
    }

    void EAGLWindow::initNativeCreatedWindow(const NameValuePairList *miscParams)
    {
        // This method is called from within create() and after parameters have been parsed.
        // If the window, view or view controller objects are nil at this point, it is safe
        // to assume that external handles are either not being used or are invalid and
        // we can create our own.
        NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

        uint w = 0, h = 0;

        ConfigOptionMap::const_iterator opt;
        ConfigOptionMap::const_iterator end = mGLSupport->getConfigOptions().end();
        NameValuePairList::const_iterator param;

        if ((opt = mGLSupport->getConfigOptions().find("Video Mode")) != end)
        {
            String val = opt->second.currentValue;
            String::size_type pos = val.find('x');

            if (pos != String::npos)
            {
                w = StringConverter::parseUnsignedInt(val.substr(0, pos));
                h = StringConverter::parseUnsignedInt(val.substr(pos + 1));
            }
        }

        // Set us up with an external window, or create our own.
        if(!mIsExternal)
        {
            mWindow = [[[UIWindow alloc] initWithFrame:CGRectMake(0, 0, w, h)] retain];
        }

        OgreAssert(mWindow != nil, "EAGLWindow: Failed to create native window");

        // Set up the view
        if(!mUsingExternalView)
        {
            mView = [[EAGLView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
            mView.opaque = YES;

            // Use the default scale factor of the screen
            // See Apple's documentation on supporting high resolution devices for more info
#if __IPHONE_4_0
            if(mIsContentScalingSupported)
                mView.contentScaleFactor = mContentScalingFactor;
#endif
        }

        OgreAssert(mView != nil, "EAGLWindow: Failed to create view");

        OgreAssert([mView.layer isKindOfClass:[CAEAGLLayer class]], "EAGLWindow: View's Core Animation layer is not a CAEAGLLayer. This is a requirement for using OpenGL ES for drawing.");
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)mView.layer;
        OgreAssert(eaglLayer != nil, "EAGLWindow: Failed to retrieve a pointer to the view's Core Animation layer");

        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        // Set up the view controller
        if(!mUsingExternalViewController)
        {
            mViewController = [[EAGLViewController alloc] init];
        }

        OgreAssert(mViewController != nil, "EAGLWindow: Failed to create view controller");
        
        if(mViewController.view != mView)
            mViewController.view = mView;

        CFDictionaryRef dict;   // TODO: Dummy dictionary for now
        if(eaglLayer)
        {
            EAGLSharegroup *group = nil;
            NameValuePairList::const_iterator option;

            if ((option = miscParams->find("externalSharegroup")) != miscParams->end())
            {
                group = (EAGLSharegroup *)StringConverter::parseUnsignedLong(option->second);
                LogManager::getSingleton().logMessage("iOS: Using an external EAGLSharegroup");
            }

            mContext = mGLSupport->createNewContext(dict, eaglLayer, group);

#if __IPHONE_4_0
            // MSAA is only supported on devices running iOS 4+
            if(mCurrentOSVersion >= 4.0)
            {
                mContext->mIsMultiSampleSupported = true;
                mContext->mNumSamples = mFSAA;
            }
#endif
        }
        
        OgreAssert(mContext != nil, "EAGLWindow: Failed to create OpenGL ES context");

        [mWindow addSubview:mViewController.view];

        if(!mUsingExternalViewController)
            mWindow.rootViewController = mViewController;

        if(!mUsingExternalView)
            [mView release];

        [mWindow makeKeyAndVisible];

        mContext->createFramebuffer();

        // If content scaling is supported, the window size will be smaller than the GL pixel buffer
        // used to render.  Report the buffer size for reference.
        StringStream ss;
    
        ss  << "iOS: Window created " << w << " x " << h
            << " with backing store size " << mContext->mBackingWidth << " x " << mContext->mBackingHeight;
        if(mIsContentScalingSupported)
        {
            ss << " using content scaling factor " << std::fixed << std::setprecision(1) << mContentScalingFactor;
        }
        LogManager::getSingleton().logMessage(ss.str());

        [pool release];
    }
    
    void EAGLWindow::create(const String& name, uint width, uint height,
                                bool fullScreen, const NameValuePairList *miscParams)
    {
        String orientation = "Landscape Right";
        short frequency = 0;
        bool vsync = false;
		int left = 0;
		int top  = 0;
        
        mIsFullScreen = fullScreen;
        mName = name;
        mWidth = width;
        mHeight = height;

        if (miscParams)
        {
            NameValuePairList::const_iterator opt;
            NameValuePairList::const_iterator end = miscParams->end();

            // Note: Some platforms support AA inside ordinary windows
            if ((opt = miscParams->find("FSAA")) != end)
            {
                mFSAA = StringConverter::parseUnsignedInt(opt->second);
            }
            
            if ((opt = miscParams->find("displayFrequency")) != end)
            {
                frequency = (short)StringConverter::parseInt(opt->second);
            }

            if ((opt = miscParams->find("contentScalingFactor")) != end)
            {
                mContentScalingFactor = StringConverter::parseReal(opt->second);
            }
            
            if ((opt = miscParams->find("vsync")) != end)
            {
                vsync = StringConverter::parseBool(opt->second);
            }

            if ((opt = miscParams->find("left")) != end)
            {
                left = StringConverter::parseInt(opt->second);
            }
            
            if ((opt = miscParams->find("top")) != end)
            {
                top = StringConverter::parseInt(opt->second);
            }
            
            if ((opt = miscParams->find("title")) != end)
            {
                mName = opt->second;
            }

            if ((opt = miscParams->find("orientation")) != end)
            {
                orientation = opt->second;
            }

            if ((opt = miscParams->find("externalWindowHandle")) != end)
            {
                mWindow = (UIWindow *)StringConverter::parseUnsignedLong(opt->second);
                mIsExternal = true;
                LogManager::getSingleton().logMessage("iOS: Using an external window handle");
            }

            if ((opt = miscParams->find("externalViewHandle")) != end)
            {
                mView = (EAGLView *)StringConverter::parseUnsignedLong(opt->second);
                CGRect b = [mView bounds];
                mWidth = b.size.width;
                mHeight = b.size.height;
                mUsingExternalView = true;
                LogManager::getSingleton().logMessage("iOS: Using an external view handle");
            }

            if ((opt = miscParams->find("externalViewControllerHandle")) != end)
            {
                mViewController = (EAGLViewController *)StringConverter::parseUnsignedLong(opt->second);
                if(mViewController.view != nil)
                    mView = (EAGLView *)mViewController.view;
                mUsingExternalViewController = true;
                LogManager::getSingleton().logMessage("iOS: Using an external view controller handle");
            }
		}

        initNativeCreatedWindow(miscParams);

        left = top = 0;
		mLeft = left;
		mTop = top;

        // Resize, taking content scaling factor into account
        resize(mWidth * mContentScalingFactor, mHeight * mContentScalingFactor);

		mActive = true;
		mVisible = true;
		mClosed = false;
    }

    void EAGLWindow::swapBuffers(bool waitForVSync)
    {
        if (mClosed)
        {
            return;
        }

#if __IPHONE_4_0
        if(mContext->mIsMultiSampleSupported && mContext->mNumSamples > 0)
        {
            glDisable(GL_SCISSOR_TEST);     
            glBindFramebufferOES(GL_READ_FRAMEBUFFER_APPLE, mContext->mFSAAFramebuffer);
            GL_CHECK_ERROR
            glBindFramebufferOES(GL_DRAW_FRAMEBUFFER_APPLE, mContext->mViewFramebuffer);
            GL_CHECK_ERROR
            glResolveMultisampleFramebufferAPPLE();
            GL_CHECK_ERROR
        }

        // Framebuffer discard is only supported on devices running iOS 4+
        if(mCurrentOSVersion >= 4.0)
        {
            GLenum attachments[] = { GL_COLOR_ATTACHMENT0_OES, GL_DEPTH_ATTACHMENT_OES, GL_STENCIL_ATTACHMENT_OES };
            glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 3, attachments);
            GL_CHECK_ERROR
        }
#endif
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, mContext->mViewFramebuffer);
        GL_CHECK_ERROR

        glBindRenderbufferOES(GL_RENDERBUFFER_OES, mContext->mViewRenderbuffer);
        GL_CHECK_ERROR
        if ([mContext->getContext() presentRenderbuffer:GL_RENDERBUFFER_OES] == NO)
        {
            GL_CHECK_ERROR
            OGRE_EXCEPT(Exception::ERR_RENDERINGAPI_ERROR,
                        "Failed to swap buffers in ",
                        __FUNCTION__);
        }
    }

    void EAGLWindow::getCustomAttribute( const String& name, void* pData )
    {
		if( name == "GLCONTEXT" )
		{
			*static_cast<EAGLESContext**>(pData) = mContext;
			return;
		}

        if( name == "SHAREGROUP" )
		{
            *(void**)(pData) = mContext->getContext().sharegroup;
            return;
		}

		if( name == "WINDOW" )
		{
			*(void**)(pData) = mWindow;
			return;
		}
        
		if( name == "VIEW" )
		{
			*(void**)(pData) = mViewController.view;
			return;
		}

        if( name == "VIEWCONTROLLER" )
		{
            *(void**)(pData) = mViewController;
            return;
		}
	}

    void EAGLWindow::copyContentsToMemory(const PixelBox &dst, FrameBuffer buffer)
    {
        if ((dst.left < 0) || (dst.right > mWidth) ||
			(dst.top < 0) || (dst.bottom > mHeight) ||
			(dst.front != 0) || (dst.back != 1))
		{
			OGRE_EXCEPT(Exception::ERR_INVALIDPARAMS,
				"Invalid box.",
				__FUNCTION__ );
		}

		if (buffer == FB_AUTO)
		{
			buffer = mIsFullScreen? FB_FRONT : FB_BACK;
		}

		GLenum format = GLESPixelUtil::getGLOriginFormat(dst.format);
		GLenum type = GLESPixelUtil::getGLOriginDataType(dst.format);

		if ((format == 0) || (type == 0))
		{
			OGRE_EXCEPT(Exception::ERR_INVALIDPARAMS,
				"Unsupported format.",
				__FUNCTION__ );
		}

		// Switch context if different from current one
		RenderSystem* rsys = Root::getSingleton().getRenderSystem();
		rsys->_setViewport(this->getViewport(0));

        if((dst.getWidth() * Ogre::PixelUtil::getNumElemBytes(dst.format)) & 3)
        {
            // Standard alignment of 4 is not right
            glPixelStorei(GL_PACK_ALIGNMENT, 1);
        }

		glReadPixels((GLint)dst.left, (GLint)dst.top,
			(GLsizei)dst.getWidth(), (GLsizei)dst.getHeight(),
			format, type, dst.data);

		// Restore default alignment
		glPixelStorei(GL_PACK_ALIGNMENT, 4);

		// Vertical flip
		{
			size_t rowSpan = dst.getWidth() * PixelUtil::getNumElemBytes(dst.format);
			size_t height = dst.getHeight();
			uchar *tmpData = OGRE_NEW uchar[rowSpan * height];
			uchar *srcRow = (uchar *)dst.data, *tmpRow = tmpData + (height - 1) * rowSpan;

			while (tmpRow >= tmpData)
			{
				memcpy(tmpRow, srcRow, rowSpan);
				srcRow += rowSpan;
				tmpRow -= rowSpan;
			}
			memcpy(dst.data, tmpData, rowSpan * height);

			OGRE_DELETE [] tmpData;
		}

    }
}
