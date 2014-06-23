/*
-----------------------------------------------------------------------------
This source file is part of OGRE
(Object-oriented Graphics Rendering Engine)
For the latest info, see http://www.ogre3d.org

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
/*
#include "Vao/OgreGL3PlusVertexBufferPacked.h"
#include "Vao/OgreGL3PlusVaoManager.h"

namespace Ogre
{
    GL3PlusVertexBufferPacked::GL3PlusVertexBufferPacked(
                                            size_t internalBufferStart, size_t numElements,
                                            uint32 bytesPerElement, BufferType bufferType,
                                            void *initialData, bool keepAsShadow,
                                            VaoManager *vaoManager,
                                            const VertexElement2Vec &vertexElements,
                                            GLuint vboName ) :
        VertexBufferPacked( internalBufferStart, numElements, bytesPerElement, bufferType,
                            initialData, keepAsShadow, vaoManager, vertexElements ),
        mBufferInterface( vboName, GL_ARRAY_BUFFER )
    {
        if( initialData )
        {
            mBufferInterface.upload( initialData, 0, numElements );
        }
    }
    //-----------------------------------------------------------------------------------
    GL3PlusVertexBufferPacked::~GL3PlusVertexBufferPacked()
    {
    }
    //-----------------------------------------------------------------------------------
    void* GL3PlusVertexBufferPacked::mapImpl( size_t elementStart, size_t elementCount,
                                              MappingState prevMappingState )
    {
        return mBufferInterface.map( elementStart, elementCount, prevMappingState );
    }
    //-----------------------------------------------------------------------------------
    void GL3PlusVertexBufferPacked::unmapImpl( UnmapOptions unmapOption )
    {
        mBufferInterface.unmap( unmapOption );
    }
    //-----------------------------------------------------------------------------------
    void GL3PlusVertexBufferPacked::upload( void *data, size_t elementStart, size_t elementCount )
    {
        VertexBufferPacked::upload( data, elementStart, elementCount );
        mBufferInterface.upload( data, elementStart, elementCount );
    }
}
*/
