/*
-----------------------------------------------------------------------------
This source file is part of OGRE
    (Object-oriented Graphics Rendering Engine)
For the latest info, see http://www.ogre3d.org/

Copyright (c) 2000-2014 Torus Knot Software Ltd

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
-----------------------------------------------------------------------------
*/
#ifndef _OgreHlmsPbsMobilePrerequisites_H_
#define _OgreHlmsPbsMobilePrerequisites_H_

#if OGRE_PLATFORM == OGRE_PLATFORM_WIN32 || OGRE_PLATFORM == OGRE_PLATFORM_WINRT
#   if defined( OGRE_STATIC_LIB ) || defined( OGRE_PBS_MOBILE_STATIC_LIB )
#       define _OgreHlmsPbsMobileExport
#   else
#       if defined( OgreHlmsPbsMobile_EXPORTS )
#           define _OgreHlmsPbsMobileExport __declspec( dllexport )
#       else
#           if defined( __MINGW32__ )
#               define _OgreHlmsPbsMobileExport
#           else
#               define _OgreHlmsPbsMobileExport __declspec( dllimport )
#           endif
#       endif
#   endif
#elif defined ( OGRE_GCC_VISIBILITY )
#   define _OgreHlmsPbsMobileExport __attribute__ ((visibility("default")))
#else
#   define _OgreHlmsPbsMobileExport
#endif 

namespace Ogre
{
    enum PbsMobileTextureTypes
    {
        PBSM_DIFFUSE,
        PBSM_NORMAL,
        PBSM_SPECULAR,
        PBSM_REFLECTION,
        PBSM_DETAIL0,
        PBSM_DETAIL1,
        PBSM_DETAIL2,
        PBSM_DETAIL3,
        PBSM_DETAIL0_NM,
        PBSM_DETAIL1_NM,
        PBSM_DETAIL2_NM,
        PBSM_DETAIL3_NM,
        PBSM_MAX_TEXTURE_TYPES
    };

    enum PbsMobileUvSourceType
    {
        PBSM_SOURCE_DIFFUSE,
        PBSM_SOURCE_NORMAL,
        PBSM_SOURCE_SPECULAR,
        PBSM_SOURCE_DETAIL0,
        PBSM_SOURCE_DETAIL1,
        PBSM_SOURCE_DETAIL2,
        PBSM_SOURCE_DETAIL3,
        NUM_PBSM_SOURCES
    };

    enum PbsMobileBlendModes
    {
        /// Regular alpha blending
        PBSM_BLEND_NORMAL_NON_PREMUL,
        /// Premultiplied alpha blending
        PBSM_BLEND_NORMAL_PREMUL,
        PBSM_BLEND_ADD,
        PBSM_BLEND_SUBTRACT,
        PBSM_BLEND_MULTIPLY,
        PBSM_BLEND_MULTIPLY2X,
        PBSM_BLEND_SCREEN,
        PBSM_BLEND_OVERLAY,
        PBSM_BLEND_LIGHTEN,
        PBSM_BLEND_DARKEN,
        PBSM_BLEND_GRAIN_EXTRACT,
        PBSM_BLEND_GRAIN_MERGE,
        PBSM_BLEND_DIFFERENCE,
        NUM_PBSM_BLEND_MODES
    };
}

#endif
