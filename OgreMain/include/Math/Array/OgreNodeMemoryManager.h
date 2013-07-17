/*
-----------------------------------------------------------------------------
This source file is part of OGRE
    (Object-oriented Graphics Rendering Engine)
For the latest info, see http://www.ogre3d.org/

Copyright (c) 2000-2013 Torus Knot Software Ltd

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
#ifndef __NodeMemoryManager_H__
#define __NodeMemoryManager_H__

#include "OgreTransform.h"
#include "OgreArrayMemoryManager.h"

namespace Ogre
{
	/** \addtogroup Core
	*  @{
	*/
	/** \addtogroup Memory
	*  @{
	*/

	/** Wrap-around class that contains multiple ArrayMemoryManager, one per hierarchy depth
	@remarks
		This is the main memory manager that actually manages Nodes, and have to be called
		when a new SceneNode was created, when a SceneNode gets detached from it's parent,
		when it's attached again, etc.
		@par
		Note that some SceneManager implementations (i.e. Octree like) may want to have more
		than one NodeMemoryManager, for example one per octant.
	*/
	class NodeMemoryManager
	{
		typedef vector<NodeArrayMemoryManager>::type ArrayMemoryManagerVec;
		/// ArrayMemoryManagers grouped by hierarchy depth
		ArrayMemoryManagerVec					m_memoryManagers;
		ArrayMemoryManager::RebaseListener		*m_rebaseListener;

		/// Dummy node where to point Transform::mParents[i] when they're unused slots.
		SceneNode								*m_dummyNode;
		Transform								m_dummyTransformPtrs;

		/** Makes m_memoryManagers big enough to be able to fulfill m_memoryManagers[newDepth]
		@param newDepth
			Hierarchy level depth we wish to grow to.
		*/
		void growToDepth( size_t newDepth );

	public:
		NodeMemoryManager( NodeArrayMemoryManager::RebaseListener *rebaseListener );
		~NodeMemoryManager();

		/** Requests memory for the given transform for the first, initializing values.
		@param outTransform
			Transform with filled pointers
		@param depth
			Hierarchy level depth. 0 if not connected.
		*/
		void nodeCreated( Transform &outTransform, size_t depth );

		/** Requests memory for the given transform to be attached, transferring
			existing values inside to the new memory block
		@remarks
			Do NOT call this function twice in a row without having called
			nodeDettached in the middle
		@param outTransform
			Transform with filled pointers
		@param depth
			Hierarchy level depth the node belongs to. If 0, nothing happens.
		*/
		void nodeAttached( Transform &outTransform, size_t depth );

		/** Releases current memory and requests memory from the root level
		@remarks
			Do NOT call this function twice in a row without having called
			nodeAttached in the middle
		@param outTransform
			Transform with filled pointers
		@param depth
			Current hierarchy level depth it belongs to. If 0, nothing happens.
		*/
		void nodeDettached( Transform &outTransform, size_t depth );

		/** Releases current memory
		@param outTransform
			Transform with nullified pointers
		@param depth
			Current hierarchy level depth it belongs to.
		*/
		void nodeDestroyed( Transform &outTransform, size_t depth );

		/** Retrieves the number of depth levels that have been created.
		@remarks
			The return value is equal or below m_memoryManagers.size(), you should cache
			the result instead of calling this function too often.
		*/
		size_t getNumDepths() const;

		/** Retrieves a Transform pointing to the first Node in the given depth
		@param outTransform
			[out] Transform with filled pointers to the first Node in this depth
		@param depth
			Current hierarchy level depth it belongs to.
		@return
			Number of Nodes in this depth level
		*/
		size_t getFirstNode( Transform &outTransform, size_t depth );
	};

	/** @} */
	/** @} */
}

#endif
