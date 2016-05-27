/*
-----------------------------------------------------------------------------
This source file is part of OGRE
(Object-oriented Graphics Rendering Engine)
For the latest info, see http://www.ogre3d.org

Copyright (c) 2000-2016 Torus Knot Software Ltd

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

#include "Vao/OgreMetalVaoManager.h"
#include "Vao/OgreMetalStagingBuffer.h"
#include "Vao/OgreVertexArrayObject.h"
#include "Vao/OgreMetalBufferInterface.h"
#include "Vao/OgreMetalConstBufferPacked.h"
#include "Vao/OgreMetalTexBufferPacked.h"
#include "Vao/OgreMetalUavBufferPacked.h"
#include "Vao/OgreMetalMultiSourceVertexBufferPool.h"
#include "Vao/OgreMetalDynamicBuffer.h"
#include "Vao/OgreMetalAsyncTicket.h"

#include "Vao/OgreIndirectBufferPacked.h"

#include "OgreMetalDevice.h"

#include "OgreRenderQueue.h"
#include "OgreRoot.h"
#include "OgreHlmsManager.h"

#include "OgreTimer.h"
#include "OgreStringConverter.h"

namespace Ogre
{
    MetalVaoManager::MetalVaoManager( uint8 dynamicBufferMultiplier, MetalDevice *device ) :
        mVaoNames( 1 ),
        mDevice( device ),
        mDrawId( 0 )
    {
#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE_IOS
        //On iOS alignment must match "the maximum accessed object" type. e.g.
        //if it's all float, then alignment = 4. if it's a float2, then alignment = 8.
        //The max. object is float4, so alignment = 16
        mConstBufferAlignment   = 16;
        mTexBufferAlignment     = 16;

        //Keep pools of 32MB for static buffers
        mDefaultPoolSize[CPU_INACCESSIBLE]  = 32 * 1024 * 1024;

        //Keep pools of 8MB each for dynamic buffers
        for( size_t i=CPU_ACCESSIBLE_DEFAULT; i<=CPU_ACCESSIBLE_PERSISTENT_COHERENT; ++i )
            mDefaultPoolSize[i] = 8 * 1024 * 1024;

        //TODO: iOS v3 family does support indirect buffers.
        mSupportsIndirectBuffers    = false;
#else
        //OS X restrictions.
        mConstBufferAlignment   = 256;
        mTexBufferAlignment     = 256;

        //Keep pools of 128MB for static buffers
        mDefaultPoolSize[CPU_INACCESSIBLE]  = 128 * 1024 * 1024;

        //Keep pools of 32MB each for dynamic buffers
        for( size_t i=CPU_ACCESSIBLE_DEFAULT; i<=CPU_ACCESSIBLE_PERSISTENT_COHERENT; ++i )
            mDefaultPoolSize[i] = 32 * 1024 * 1024;

        mSupportsIndirectBuffers    = true;
#endif

        mConstBufferMaxSize = 64 * 1024;        //64kb
        mTexBufferMaxSize   = 128 * 1024 * 1024;//128MB

        mSupportsPersistentMapping  = true;

        mDynamicBufferMultiplier = dynamicBufferMultiplier;

#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE_IOS
        uint32 *drawIdPtr = static_cast<uint32*>( OGRE_MALLOC_SIMD( 4096 * sizeof(uint32),
                                                                    MEMCATEGORY_GEOMETRY ) );
        for( uint32 i=0; i<4096; ++i )
            drawIdPtr[i] = i;
        mDrawId = createConstBuffer( 4096 * sizeof(uint32), BT_IMMUTABLE, drawIdPtr, false );
        OGRE_FREE_SIMD( drawIdPtr, MEMCATEGORY_GEOMETRY );
        drawIdPtr = 0;
#else
        VertexElement2Vec vertexElements;
        vertexElements.push_back( VertexElement2( VET_UINT1, VES_COUNT ) );
        uint32 *drawIdPtr = static_cast<uint32*>( OGRE_MALLOC_SIMD( 4096 * sizeof(uint32),
                                                                    MEMCATEGORY_GEOMETRY ) );
        for( uint32 i=0; i<4096; ++i )
            drawIdPtr[i] = i;
        mDrawId = createVertexBuffer( vertexElements, 4096, BT_IMMUTABLE, drawIdPtr, true );
#endif
    }
    //-----------------------------------------------------------------------------------
    MetalVaoManager::~MetalVaoManager()
    {
        destroyAllVertexArrayObjects();
        deleteAllBuffers();
    }
    //-----------------------------------------------------------------------------------
    /// Returns Greatest Common Denominator
    size_t gcd( size_t a, size_t b )
    {
        return b == 0u ? a : gcd( b, a % b );
    }
    /// Returns Least Common Multiple
    size_t lcm( size_t a, size_t b )
    {
        return a * b / gcd( a, b );
    }
    void MetalVaoManager::allocateVbo( size_t sizeBytes, size_t alignment, BufferType bufferType,
                                       size_t &outVboIdx, size_t &outBufferOffset )
    {
        assert( alignment > 0 );

#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE_IOS
        //On iOS 16 byte alignment makes it good to go for everything; but we need to satisfy
        //both original alignment for baseVertex reasons. So find LCM between both.
        alignment = lcm( alignment, 16u );
#else
        //On OSX we have several alignments (just like GL & D3D11), but it can never be lower than 4.
        alignment = std::min<size_t>( alignment, 4u );
#endif

        VboFlag vboFlag = bufferTypeToVboFlag( bufferType );

        if( bufferType >= BT_DYNAMIC_DEFAULT )
            sizeBytes   *= mDynamicBufferMultiplier;

        VboVec::const_iterator itor = mVbos[vboFlag].begin();
        VboVec::const_iterator end  = mVbos[vboFlag].end();

        //Find a suitable VBO that can hold the requested size. We prefer those free
        //blocks that have a matching stride (the current offset is a multiple of
        //bytesPerElement) in order to minimize the amount of memory padding.
        size_t bestVboIdx   = ~0;
        size_t bestBlockIdx = ~0;
        bool foundMatchingStride = false;

        while( itor != end && !foundMatchingStride )
        {
            BlockVec::const_iterator blockIt = itor->freeBlocks.begin();
            BlockVec::const_iterator blockEn = itor->freeBlocks.end();

            while( blockIt != blockEn && !foundMatchingStride )
            {
                const Block &block = *blockIt;

                //Round to next multiple of alignment
                size_t newOffset = ( (block.offset + alignment - 1) / alignment ) * alignment;

                if( sizeBytes <= block.size - (newOffset - block.offset) )
                {
                    bestVboIdx      = itor - mVbos[vboFlag].begin();
                    bestBlockIdx    = blockIt - itor->freeBlocks.begin();

                    if( newOffset == block.offset )
                        foundMatchingStride = true;
                }

                ++blockIt;
            }

            ++itor;
        }

        if( bestBlockIdx == (size_t)~0 )
        {
            bestVboIdx      = mVbos[vboFlag].size();
            bestBlockIdx    = 0;
            foundMatchingStride = true;

            Vbo newVbo;

            size_t poolSize = std::max( mDefaultPoolSize[vboFlag], sizeBytes );

            //No luck, allocate a new buffer.
            MTLResourceOptions resourceOptions = 0;

            if( vboFlag == CPU_INACCESSIBLE )
                resourceOptions = MTLResourceStorageModePrivate;
            else
            {
                resourceOptions = MTLResourceCPUCacheModeWriteCombined;
                if( vboFlag == CPU_ACCESSIBLE_DEFAULT )
                    resourceOptions |= 0;
#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE_IOS
                else if( vboFlag == CPU_ACCESSIBLE_PERSISTENT )
                    resourceOptions |= MTLResourceStorageModeShared;
#else
                else if( vboFlag == CPU_ACCESSIBLE_PERSISTENT )
                    resourceOptions |= MTLResourceStorageModeManaged;
#endif
                else if( vboFlag == CPU_ACCESSIBLE_PERSISTENT_COHERENT )
                    resourceOptions |= MTLResourceCPUCacheModeDefaultCache;
            }

            newVbo.vboName = [mDevice->mDevice newBufferWithLength:poolSize options:resourceOptions];

            if( !newVbo.vboName )
            {
                OGRE_EXCEPT( Exception::ERR_RENDERINGAPI_ERROR,
                             "Out of GPU memory or driver refused.\n"
                             "Requested: " + StringConverter::toString( poolSize ) + " bytes.",
                             "MetalVaoManager::allocateVbo" );
            }

            newVbo.sizeBytes = poolSize;
            newVbo.freeBlocks.push_back( Block( 0, poolSize ) );
            newVbo.dynamicBuffer = 0;

            if( vboFlag != CPU_INACCESSIBLE )
            {
                newVbo.dynamicBuffer = new MetalDynamicBuffer( newVbo.vboName, newVbo.sizeBytes  );
            }

            mVbos[vboFlag].push_back( newVbo );
        }

        Vbo &bestVbo        = mVbos[vboFlag][bestVboIdx];
        Block &bestBlock    = bestVbo.freeBlocks[bestBlockIdx];

        size_t newOffset = ( (bestBlock.offset + alignment - 1) / alignment ) * alignment;
        size_t padding = newOffset - bestBlock.offset;
        //Shrink our records about available data.
        bestBlock.size   -= sizeBytes + padding;
        bestBlock.offset = newOffset + sizeBytes;

        if( !foundMatchingStride )
        {
            //This is a stride changer, record as such.
            StrideChangerVec::iterator itStride = std::lower_bound( bestVbo.strideChangers.begin(),
                                                                    bestVbo.strideChangers.end(),
                                                                    newOffset, StrideChanger() );
            bestVbo.strideChangers.insert( itStride, StrideChanger( newOffset, padding ) );
        }

        if( bestBlock.size == 0 )
            bestVbo.freeBlocks.erase( bestVbo.freeBlocks.begin() + bestBlockIdx );

        outVboIdx       = bestVboIdx;
        outBufferOffset = newOffset;
    }
    //-----------------------------------------------------------------------------------
    void MetalVaoManager::deallocateVbo( size_t vboIdx, size_t bufferOffset, size_t sizeBytes,
                                         BufferType bufferType )
    {
        VboFlag vboFlag = bufferTypeToVboFlag( bufferType );

        if( bufferType >= BT_DYNAMIC_DEFAULT )
            sizeBytes *= mDynamicBufferMultiplier;

        Vbo &vbo = mVbos[vboFlag][vboIdx];
        StrideChangerVec::iterator itStride = std::lower_bound( vbo.strideChangers.begin(),
                                                                vbo.strideChangers.end(),
                                                                bufferOffset, StrideChanger() );

        if( itStride != vbo.strideChangers.end() && itStride->offsetAfterPadding == bufferOffset )
        {
            bufferOffset    -= itStride->paddedBytes;
            sizeBytes       += itStride->paddedBytes;

            vbo.strideChangers.erase( itStride );
        }

        //See if we're contiguous to a free block and make that block grow.
        vbo.freeBlocks.push_back( Block( bufferOffset, sizeBytes ) );
        mergeContiguousBlocks( vbo.freeBlocks.end() - 1, vbo.freeBlocks );
    }
    //-----------------------------------------------------------------------------------
    void MetalVaoManager::mergeContiguousBlocks( BlockVec::iterator blockToMerge,
                                                 BlockVec &blocks )
    {
        BlockVec::iterator itor = blocks.begin();
        BlockVec::iterator end  = blocks.end();

        while( itor != end )
        {
            if( itor->offset + itor->size == blockToMerge->offset )
            {
                itor->size += blockToMerge->size;
                size_t idx = itor - blocks.begin();

                //When blockToMerge is the last one, its index won't be the same
                //after removing the other iterator, they will swap.
                if( idx == blocks.size() - 1 )
                    idx = blockToMerge - blocks.begin();

                efficientVectorRemove( blocks, blockToMerge );

                blockToMerge = blocks.begin() + idx;
                itor = blocks.begin();
                end  = blocks.end();
            }
            else if( blockToMerge->offset + blockToMerge->size == itor->offset )
            {
                blockToMerge->size += itor->size;
                size_t idx = blockToMerge - blocks.begin();

                //When blockToMerge is the last one, its index won't be the same
                //after removing the other iterator, they will swap.
                if( idx == blocks.size() - 1 )
                    idx = itor - blocks.begin();

                efficientVectorRemove( blocks, itor );

                blockToMerge = blocks.begin() + idx;
                itor = blocks.begin();
                end  = blocks.end();
            }
            else
            {
                ++itor;
            }
        }
    }
    //-----------------------------------------------------------------------------------
    VertexBufferPacked* MetalVaoManager::createVertexBufferImpl( size_t numElements,
                                                                   uint32 bytesPerElement,
                                                                   BufferType bufferType,
                                                                   void *initialData, bool keepAsShadow,
                                                                   const VertexElement2Vec &vElements )
    {
        size_t vboIdx;
        size_t bufferOffset;

        allocateVbo( numElements * bytesPerElement, bytesPerElement, bufferType, vboIdx, bufferOffset );

        VboFlag vboFlag = bufferTypeToVboFlag( bufferType );
        Vbo &vbo = mVbos[vboFlag][vboIdx];
        MetalBufferInterface *bufferInterface = new MetalBufferInterface( vboIdx, vbo.vboName,
                                                                          vbo.dynamicBuffer );

        VertexBufferPacked *retVal = OGRE_NEW VertexBufferPacked(
                                                        bufferOffset, numElements, bytesPerElement,
                                                        bufferType, initialData, keepAsShadow,
                                                        this, bufferInterface, vElements, 0, 0, 0 );

        if( initialData )
            bufferInterface->_firstUpload( initialData, 0, numElements );

        return retVal;
    }
    //-----------------------------------------------------------------------------------
    void MetalVaoManager::destroyVertexBufferImpl( VertexBufferPacked *vertexBuffer )
    {
        MetalBufferInterface *bufferInterface = static_cast<MetalBufferInterface*>(
                                                        vertexBuffer->getBufferInterface() );


        deallocateVbo( bufferInterface->getVboPoolIndex(),
                       vertexBuffer->_getInternalBufferStart() * vertexBuffer->getBytesPerElement(),
                       vertexBuffer->getNumElements() * vertexBuffer->getBytesPerElement(),
                       vertexBuffer->getBufferType() );
    }
    //-----------------------------------------------------------------------------------
    MultiSourceVertexBufferPool* MetalVaoManager::createMultiSourceVertexBufferPoolImpl(
                                                const VertexElement2VecVec &vertexElementsBySource,
                                                size_t maxNumVertices, size_t totalBytesPerVertex,
                                                BufferType bufferType )
    {
        size_t vboIdx;
        size_t bufferOffset;

        allocateVbo( maxNumVertices * totalBytesPerVertex, totalBytesPerVertex,
                     bufferType, vboIdx, bufferOffset );

        VboFlag vboFlag = bufferTypeToVboFlag( bufferType );

        const Vbo &vbo = mVbos[vboFlag][vboIdx];

        return OGRE_NEW MetalMultiSourceVertexBufferPool( vboIdx, vbo.vboName, vertexElementsBySource,
                                                          maxNumVertices, bufferType,
                                                          bufferOffset, this );
    }
    //-----------------------------------------------------------------------------------
    IndexBufferPacked* MetalVaoManager::createIndexBufferImpl( size_t numElements,
                                                                 uint32 bytesPerElement,
                                                                 BufferType bufferType,
                                                                 void *initialData, bool keepAsShadow )
    {
        size_t vboIdx;
        size_t bufferOffset;

        allocateVbo( numElements * bytesPerElement, bytesPerElement, bufferType, vboIdx, bufferOffset );

        VboFlag vboFlag = bufferTypeToVboFlag( bufferType );

        Vbo &vbo = mVbos[vboFlag][vboIdx];
        MetalBufferInterface *bufferInterface = new MetalBufferInterface( vboIdx, vbo.vboName,
                                                                          vbo.dynamicBuffer );
        IndexBufferPacked *retVal = OGRE_NEW IndexBufferPacked(
                                                        bufferOffset, numElements, bytesPerElement,
                                                        bufferType, initialData, keepAsShadow,
                                                        this, bufferInterface );

        if( initialData )
            bufferInterface->_firstUpload( initialData, 0, numElements );

        return retVal;
    }
    //-----------------------------------------------------------------------------------
    void MetalVaoManager::destroyIndexBufferImpl( IndexBufferPacked *indexBuffer )
    {
        MetalBufferInterface *bufferInterface = static_cast<MetalBufferInterface*>(
                                                        indexBuffer->getBufferInterface() );


        deallocateVbo( bufferInterface->getVboPoolIndex(),
                       indexBuffer->_getInternalBufferStart() * indexBuffer->getBytesPerElement(),
                       indexBuffer->getNumElements() * indexBuffer->getBytesPerElement(),
                       indexBuffer->getBufferType() );
    }
    //-----------------------------------------------------------------------------------
    ConstBufferPacked* MetalVaoManager::createConstBufferImpl( size_t sizeBytes, BufferType bufferType,
                                                                 void *initialData, bool keepAsShadow )
    {
        size_t vboIdx;
        size_t bufferOffset;

        size_t alignment = mConstBufferAlignment;

        size_t bindableSize = sizeBytes;

        VboFlag vboFlag = bufferTypeToVboFlag( bufferType );

        if( bufferType >= BT_DYNAMIC_DEFAULT )
        {
            //For dynamic buffers, the size will be 3x times larger
            //(depending on mDynamicBufferMultiplier); we need the
            //offset after each map to be aligned; and for that, we
            //sizeBytes to be multiple of alignment.
            sizeBytes = ( (sizeBytes + alignment - 1) / alignment ) * alignment;
        }

        allocateVbo( sizeBytes, alignment, bufferType, vboIdx, bufferOffset );

        Vbo &vbo = mVbos[vboFlag][vboIdx];
        MetalBufferInterface *bufferInterface = new MetalBufferInterface( vboIdx, vbo.vboName,
                                                                              vbo.dynamicBuffer );
        ConstBufferPacked *retVal = OGRE_NEW MetalConstBufferPacked(
                                                        bufferOffset, sizeBytes, 1,
                                                        bufferType, initialData, keepAsShadow,
                                                        this, bufferInterface, bindableSize );

        if( initialData )
            bufferInterface->_firstUpload( initialData, 0, sizeBytes );

        return retVal;
    }
    //-----------------------------------------------------------------------------------
    void MetalVaoManager::destroyConstBufferImpl( ConstBufferPacked *constBuffer )
    {
        MetalBufferInterface *bufferInterface = static_cast<MetalBufferInterface*>(
                                                        constBuffer->getBufferInterface() );


        deallocateVbo( bufferInterface->getVboPoolIndex(),
                       constBuffer->_getInternalBufferStart() * constBuffer->getBytesPerElement(),
                       constBuffer->getNumElements() * constBuffer->getBytesPerElement(),
                       constBuffer->getBufferType() );
    }
    //-----------------------------------------------------------------------------------
    TexBufferPacked* MetalVaoManager::createTexBufferImpl( PixelFormat pixelFormat, size_t sizeBytes,
                                                           BufferType bufferType,
                                                           void *initialData, bool keepAsShadow )
    {
        size_t vboIdx;
        size_t bufferOffset;

        size_t alignment = mTexBufferAlignment;

        VboFlag vboFlag = bufferTypeToVboFlag( bufferType );

        if( bufferType >= BT_DYNAMIC_DEFAULT )
        {
            //For dynamic buffers, the size will be 3x times larger
            //(depending on mDynamicBufferMultiplier); we need the
            //offset after each map to be aligned; and for that, we
            //sizeBytes to be multiple of alignment.
            sizeBytes = ( (sizeBytes + alignment - 1) / alignment ) * alignment;
        }

        allocateVbo( sizeBytes, alignment, bufferType, vboIdx, bufferOffset );

        Vbo &vbo = mVbos[vboFlag][vboIdx];
        MetalBufferInterface *bufferInterface = new MetalBufferInterface( vboIdx, vbo.vboName,
                                                                          vbo.dynamicBuffer );
        TexBufferPacked *retVal = OGRE_NEW MetalTexBufferPacked(
                                                        bufferOffset, sizeBytes, 1,
                                                        bufferType, initialData, keepAsShadow,
                                                        this, bufferInterface, pixelFormat );

        if( initialData )
            bufferInterface->_firstUpload( initialData, 0, sizeBytes );

        return retVal;
    }
    //-----------------------------------------------------------------------------------
    void MetalVaoManager::destroyTexBufferImpl( TexBufferPacked *texBuffer )
    {
        MetalBufferInterface *bufferInterface = static_cast<MetalBufferInterface*>(
                                                        texBuffer->getBufferInterface() );


        deallocateVbo( bufferInterface->getVboPoolIndex(),
                       texBuffer->_getInternalBufferStart() * texBuffer->getBytesPerElement(),
                       texBuffer->getNumElements() * texBuffer->getBytesPerElement(),
                       texBuffer->getBufferType() );
    }
    //-----------------------------------------------------------------------------------
    UavBufferPacked* MetalVaoManager::createUavBufferImpl( size_t numElements, uint32 bytesPerElement,
                                                           uint32 bindFlags,
                                                           void *initialData, bool keepAsShadow )
    {
        size_t vboIdx;
        size_t bufferOffset;

        size_t alignment = mUavBufferAlignment;

        const BufferType bufferType = BT_DEFAULT;
        VboFlag vboFlag = bufferTypeToVboFlag( bufferType );

        allocateVbo( numElements * bytesPerElement, alignment, bufferType, vboIdx, bufferOffset );

        Vbo &vbo = mVbos[vboFlag][vboIdx];
        MetalBufferInterface *bufferInterface = new MetalBufferInterface( vboIdx, vbo.vboName,
                                                                          vbo.dynamicBuffer );
        UavBufferPacked *retVal = OGRE_NEW MetalUavBufferPacked(
                                                        bufferOffset, numElements, bytesPerElement,
                                                        bindFlags, initialData, keepAsShadow,
                                                        this, bufferInterface );

        if( initialData )
            bufferInterface->_firstUpload( initialData, 0, numElements );

        return retVal;
    }
    //-----------------------------------------------------------------------------------
    void MetalVaoManager::destroyUavBufferImpl( UavBufferPacked *uavBuffer )
    {
        MetalBufferInterface *bufferInterface = static_cast<MetalBufferInterface*>(
                                                        uavBuffer->getBufferInterface() );


        deallocateVbo( bufferInterface->getVboPoolIndex(),
                       uavBuffer->_getInternalBufferStart() * uavBuffer->getBytesPerElement(),
                       uavBuffer->getNumElements() * uavBuffer->getBytesPerElement(),
                       uavBuffer->getBufferType() );
    }
    //-----------------------------------------------------------------------------------
    IndirectBufferPacked* MetalVaoManager::createIndirectBufferImpl( size_t sizeBytes,
                                                                     BufferType bufferType,
                                                                     void *initialData,
                                                                     bool keepAsShadow )
    {
        const size_t alignment = 4;
        size_t bufferOffset = 0;

        if( bufferType >= BT_DYNAMIC_DEFAULT )
        {
            //For dynamic buffers, the size will be 3x times larger
            //(depending on mDynamicBufferMultiplier); we need the
            //offset after each map to be aligned; and for that, we
            //sizeBytes to be multiple of alignment.
            sizeBytes = ( (sizeBytes + alignment - 1) / alignment ) * alignment;
        }

        MetalBufferInterface *bufferInterface = 0;
        if( mSupportsIndirectBuffers )
        {
            size_t vboIdx;
            VboFlag vboFlag = bufferTypeToVboFlag( bufferType );

            allocateVbo( sizeBytes, alignment, bufferType, vboIdx, bufferOffset );

            Vbo &vbo = mVbos[vboFlag][vboIdx];
            bufferInterface = new MetalBufferInterface( vboIdx, vbo.vboName, vbo.dynamicBuffer );
        }

        IndirectBufferPacked *retVal = OGRE_NEW IndirectBufferPacked(
                                                        bufferOffset, sizeBytes, 1,
                                                        bufferType, initialData, keepAsShadow,
                                                        this, bufferInterface );

        if( initialData )
        {
            if( mSupportsIndirectBuffers )
            {
                bufferInterface->_firstUpload( initialData, 0, sizeBytes );
            }
            else
            {
                memcpy( retVal->getSwBufferPtr(), initialData, sizeBytes );
            }
        }

        return retVal;
    }
    //-----------------------------------------------------------------------------------
    void MetalVaoManager::destroyIndirectBufferImpl( IndirectBufferPacked *indirectBuffer )
    {
        if( mSupportsIndirectBuffers )
        {
            MetalBufferInterface *bufferInterface = static_cast<MetalBufferInterface*>(
                        indirectBuffer->getBufferInterface() );


            deallocateVbo( bufferInterface->getVboPoolIndex(),
                           indirectBuffer->_getInternalBufferStart() *
                                indirectBuffer->getBytesPerElement(),
                           indirectBuffer->getNumElements() * indirectBuffer->getBytesPerElement(),
                           indirectBuffer->getBufferType() );
        }
    }
    //-----------------------------------------------------------------------------------
    VertexArrayObject* MetalVaoManager::createVertexArrayObjectImpl(
                                                            const VertexBufferPackedVec &vertexBuffers,
                                                            IndexBufferPacked *indexBuffer,
                                                            OperationType opType )
    {
        HlmsManager *hlmsManager = Root::getSingleton().getHlmsManager();
        VertexElement2VecVec vertexElements = VertexArrayObject::getVertexDeclaration( vertexBuffers );
        const uint8 inputLayout = hlmsManager->_addInputLayoutId( vertexElements, opType );

        VaoVec::iterator itor = findVao( vertexBuffers, indexBuffer, opType );

        const uint32 renderQueueId = generateRenderQueueId( itor->vaoName, mNumGeneratedVaos );

        VertexArrayObject *retVal = OGRE_NEW VertexArrayObject( itor->vaoName,
                                                                renderQueueId,
                                                                inputLayout,
                                                                vertexBuffers,
                                                                indexBuffer,
                                                                opType );

        return retVal;
    }
    //-----------------------------------------------------------------------------------
    void MetalVaoManager::destroyVertexArrayObjectImpl( VertexArrayObject *vao )
    {
        OGRE_DELETE vao;
    }
    //-----------------------------------------------------------------------------------
    MetalVaoManager::VaoVec::iterator MetalVaoManager::findVao(
                                                        const VertexBufferPackedVec &vertexBuffers,
                                                        IndexBufferPacked *indexBuffer,
                                                        OperationType opType )
    {
        Vao vao;

        vao.operationType = opType;
        vao.vertexBuffers.reserve( vertexBuffers.size() );

        {
            VertexBufferPackedVec::const_iterator itor = vertexBuffers.begin();
            VertexBufferPackedVec::const_iterator end  = vertexBuffers.end();

            while( itor != end )
            {
                Vao::VertexBinding vertexBinding;
                vertexBinding.vertexBufferVbo   = static_cast<MetalBufferInterface*>(
                                                        (*itor)->getBufferInterface() )->getVboName();
                vertexBinding.vertexElements    = (*itor)->getVertexElements();
                vertexBinding.instancingDivisor = 0;

                /*const MultiSourceVertexBufferPool *multiSourcePool = (*itor)->getMultiSourcePool();
                if( multiSourcePool )
                {
                    vertexBinding.offset = multiSourcePool->getBytesOffsetToSource(
                                                            (*itor)->_getSourceIndex() );
                }*/

                vao.vertexBuffers.push_back( vertexBinding );

                ++itor;
            }
        }

        //vao.refCount = 0;

        if( indexBuffer )
        {
            vao.indexBufferVbo  = static_cast<MetalBufferInterface*>(
                                    indexBuffer->getBufferInterface() )->getVboName();
            vao.indexType       = indexBuffer->getIndexType();
        }
        else
        {
            vao.indexBufferVbo  = 0;
            vao.indexType       = IndexBufferPacked::IT_16BIT;
        }

        bool bFound = false;
        VaoVec::iterator itor = mVaos.begin();
        VaoVec::iterator end  = mVaos.end();

        while( itor != end && !bFound )
        {
            if( itor->operationType == vao.operationType &&
                itor->indexBufferVbo == vao.indexBufferVbo &&
                itor->indexType == vao.indexType &&
                itor->vertexBuffers == vao.vertexBuffers )
            {
                bFound = true;
            }
            else
            {
                ++itor;
            }
        }

        if( !bFound )
        {
            vao.vaoName = createVao( vao );
            mVaos.push_back( vao );
            itor = mVaos.begin() + mVaos.size() - 1;
        }

        //++itor->refCount;

        return itor;
    }
    //-----------------------------------------------------------------------------------
    uint32 MetalVaoManager::createVao( const Vao &vaoRef )
    {
        return mVaoNames++;
    }
    //-----------------------------------------------------------------------------------
    uint32 MetalVaoManager::generateRenderQueueId( uint32 vaoName, uint32 uniqueVaoId )
    {
        //Mix mNumGeneratedVaos with the D3D11 Vao for better sorting purposes:
        //  If we only use the D3D11's vao, the RQ will sort Meshes with
        //  multiple submeshes mixed with other meshes.
        //  For cache locality, and assuming all of them have the same GL vao,
        //  we prefer the RQ to sort:
        //      1. Mesh A - SubMesh 0
        //      2. Mesh A - SubMesh 1
        //      3. Mesh B - SubMesh 0
        //      4. Mesh B - SubMesh 1
        //      5. Mesh D - SubMesh 0
        //  If we don't mix mNumGeneratedVaos in it; the following could be possible:
        //      1. Mesh B - SubMesh 1
        //      2. Mesh D - SubMesh 0
        //      3. Mesh A - SubMesh 1
        //      4. Mesh B - SubMesh 0
        //      5. Mesh A - SubMesh 0
        //  Thus thrashing the cache unnecessarily.
        const int bitsVaoGl  = 5;
        const uint32 maskVaoGl  = OGRE_RQ_MAKE_MASK( bitsVaoGl );
        const uint32 maskVao    = OGRE_RQ_MAKE_MASK( RqBits::MeshBits - bitsVaoGl );

        const uint32 shiftVaoGl     = RqBits::MeshBits - bitsVaoGl;

        uint32 renderQueueId =
                ( (vaoName & maskVaoGl) << shiftVaoGl ) |
                (uniqueVaoId & maskVao);

        return renderQueueId;
    }
    //-----------------------------------------------------------------------------------
    StagingBuffer* MetalVaoManager::createStagingBuffer( size_t sizeBytes, bool forUpload )
    {
        sizeBytes = std::max<size_t>( sizeBytes, 4 * 1024 * 1024 );
        sizeBytes = alignToNextMultiple( sizeBytes, 4u );

        MTLResourceOptions resourceOptions = 0;

        if( forUpload )
            resourceOptions = MTLResourceCPUCacheModeWriteCombined|MTLResourceStorageModeShared;
        else
            resourceOptions = MTLResourceCPUCacheModeDefaultCache|MTLResourceStorageModeShared;

        id<MTLBuffer> bufferName = [mDevice->mDevice newBufferWithLength:sizeBytes
                                                                         options:resourceOptions];

        MetalStagingBuffer *stagingBuffer = OGRE_NEW MetalStagingBuffer( 0, sizeBytes, this, forUpload,
                                                                         bufferName, mDevice );
        mRefedStagingBuffers[forUpload].push_back( stagingBuffer );

        return stagingBuffer;
    }
    //-----------------------------------------------------------------------------------
    AsyncTicketPtr MetalVaoManager::createAsyncTicket( BufferPacked *creator,
                                                         StagingBuffer *stagingBuffer,
                                                         size_t elementStart, size_t elementCount )
    {
        return AsyncTicketPtr( OGRE_NEW MetalAsyncTicket( creator, stagingBuffer,
                                                          elementStart, elementCount, mDevice ) );
    }
    //-----------------------------------------------------------------------------------
    void MetalVaoManager::_update(void)
    {
        VaoManager::_update();

        unsigned long currentTimeMs = mTimer->getMilliseconds();

        if( currentTimeMs >= mNextStagingBufferTimestampCheckpoint )
        {
            mNextStagingBufferTimestampCheckpoint = (unsigned long)(~0);

            for( size_t i=0; i<2; ++i )
            {
                StagingBufferVec::iterator itor = mZeroRefStagingBuffers[i].begin();
                StagingBufferVec::iterator end  = mZeroRefStagingBuffers[i].end();

                while( itor != end )
                {
                    StagingBuffer *stagingBuffer = *itor;

                    mNextStagingBufferTimestampCheckpoint = std::min(
                                                    mNextStagingBufferTimestampCheckpoint,
                                                    stagingBuffer->getLastUsedTimestamp() +
                                                    currentTimeMs );

                    /*if( stagingBuffer->getLastUsedTimestamp() - currentTimeMs >
                        stagingBuffer->getUnfencedTimeThreshold() )
                    {
                        static_cast<MetalStagingBuffer*>( stagingBuffer )->cleanUnfencedHazards();
                    }*/

                    if( stagingBuffer->getLastUsedTimestamp() - currentTimeMs >
                        stagingBuffer->getLifetimeThreshold() )
                    {
                        //Time to delete this buffer.
                        delete *itor;

                        itor = efficientVectorRemove( mZeroRefStagingBuffers[i], itor );
                        end  = mZeroRefStagingBuffers[i].end();
                    }
                    else
                    {
                        ++itor;
                    }
                }
            }
        }

        if( !mDelayedDestroyBuffers.empty() &&
            mDelayedDestroyBuffers.front().frameNumDynamic == mDynamicBufferCurrentFrame )
        {
            waitForTailFrameToFinish();
            destroyDelayedBuffers( mDynamicBufferCurrentFrame );
        }

        mDynamicBufferCurrentFrame = (mDynamicBufferCurrentFrame + 1) % mDynamicBufferMultiplier;
    }
    //-----------------------------------------------------------------------------------
    uint8 MetalVaoManager::waitForTailFrameToFinish(void)
    {
        //Don't wait because MetalRenderSystem::_beginFrameOnce does a global waiting for us.
        return mDynamicBufferCurrentFrame;
    }
    //-----------------------------------------------------------------------------------
    dispatch_semaphore_t MetalVaoManager::waitFor( dispatch_semaphore_t fenceName, MetalDevice *device )
    {
        dispatch_time_t timeout = DISPATCH_TIME_NOW;
        while( true )
        {
            long result = dispatch_semaphore_wait( fenceName, DISPATCH_TIME_FOREVER );

            if( result == 0 )
                return 0; //Success waiting.

            if( timeout == DISPATCH_TIME_NOW )
            {
                // After the first time, need to start flushing, and wait for a looong time.
                timeout = DISPATCH_TIME_FOREVER;
                device->commitAndNextCommandBuffer();
            }
            else if( result < 0 )
            {
                OGRE_EXCEPT( Exception::ERR_RENDERINGAPI_ERROR,
                             "Failure while waiting for a MetalFence. Could be out of GPU memory. "
                             "Update your video card drivers. If that doesn't help, "
                             "contact the developers. Error code: " + StringConverter::toString( result ),
                             "MetalStagingBuffer::wait" );

                return fenceName;
            }
        }

        return 0;
    }
    //-----------------------------------------------------------------------------------
    MetalVaoManager::VboFlag MetalVaoManager::bufferTypeToVboFlag( BufferType bufferType )
    {
        return static_cast<VboFlag>( std::max( 0, (bufferType - BT_DYNAMIC_DEFAULT) +
                                                    CPU_ACCESSIBLE_DEFAULT ) );
    }
}

