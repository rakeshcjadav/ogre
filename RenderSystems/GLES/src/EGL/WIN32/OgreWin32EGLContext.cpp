/*
-----------------------------------------------------------------------------
This source file is part of OGRE
    (Object-oriented Graphics Rendering Engine)
For the latest info, see http://www.ogre3d.org/

Copyright (c) 2008 Renato Araujo Oliveira Filho <renatox@gmail.com>
Copyright (c) 2000-2006 Torus Knot Software Ltd
Also see acknowledgements in Readme.html

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU Lesser General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place - Suite 330, Boston, MA 02111-1307, USA, or go to
http://www.gnu.org/copyleft/lesser.txt.

You may alternatively use this source under the terms of a specific version of
the OGRE Unrestricted License provided you have obtained such a license from
Torus Knot Software Ltd.
-----------------------------------------------------------------------------
*/
#include "OgreGLESRenderSystem.h"

#include "OgreEGLSupport.h"
#include "OgreWin32EGLContext.h"

#include "OgreRoot.h"

namespace Ogre {
    Win32EGLContext::Win32EGLContext(EGLDisplay eglDisplay, 
							const EGLSupport* glsupport,
                           ::EGLConfig glconfig,
                           ::EGLSurface drawable)
        : EGLContext(eglDisplay, glsupport, glconfig, drawable)
    {
    }

    Win32EGLContext::~Win32EGLContext()
    {
    }

    GLESContext* Win32EGLContext::clone() const
    {
        return new Win32EGLContext(mEglDisplay ,mGLSupport, mConfig, mDrawable);
    }
}
