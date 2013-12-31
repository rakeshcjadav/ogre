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
#include "OgreStableHeaders.h"
#include "Animation/OgreSkeletonDef.h"
#include "Animation/OgreSkeletonManager.h"

#include "OgreSkeleton.h"

namespace Ogre
{
    //-----------------------------------------------------------------------
	template<> SkeletonManager* Singleton<SkeletonManager>::msSingleton = 0;
	SkeletonManager* SkeletonManager::getSingletonPtr(void)
    {
        return msSingleton;
    }
	SkeletonManager& SkeletonManager::getSingleton(void)
    {  
        assert( msSingleton );  return ( *msSingleton );  
    }
    //-----------------------------------------------------------------------
	SkeletonManager::SkeletonManager()
	{
    }
	//-----------------------------------------------------------------------
	SkeletonManager::~SkeletonManager()
	{
	}
	//-----------------------------------------------------------------------
	SkeletonDefPtr SkeletonManager::getSkeletonDef( Skeleton *oldSkeletonBase )
	{
		IdString idName( oldSkeletonBase->getName() );
		SkeletonDefPtr retVal;
		SkeletonDefMap::iterator itor = mSkeletonDefs.find( idName );
		if( itor == mSkeletonDefs.end() )
		{
			oldSkeletonBase->load();
			retVal = SkeletonDefPtr( new SkeletonDef( oldSkeletonBase, 1.0f ) );
			mSkeletonDefs[idName] = retVal;
		}
		else
		{
			retVal = itor->second;
		}

		return retVal;
	}
    //-----------------------------------------------------------------------
	SkeletonDefPtr SkeletonManager::getSkeletonDef( const String &name, const String& groupName )
    {
		IdString idName( name );
		SkeletonDefPtr retVal;
		SkeletonDefMap::iterator itor = mSkeletonDefs.find( name );
		if( itor == mSkeletonDefs.end() )
		{
			Skeleton *oldSkeleton = OGRE_NEW Skeleton( 0, name, 0, groupName, false, 0 );
			oldSkeleton->load();
			if( oldSkeleton->isLoaded() )
				retVal = SkeletonDefPtr( new SkeletonDef( oldSkeleton, 1.0f ) );
			delete oldSkeleton;

			if( retVal.isNull() )
			{
				OGRE_EXCEPT( Exception::ERR_FILE_NOT_FOUND, "Can't find Skeleton '" + name + "'",
							 "SkeletonManager::getSkeletonDef" );
			}

			mSkeletonDefs[idName] = retVal;
		}
		else
		{
			retVal = itor->second;
		}

		return retVal;
	}
	//-----------------------------------------------------------------------
	void SkeletonManager::add( SkeletonDefPtr skeletonDef )
	{
		IdString idName( skeletonDef->getName() );
		if( mSkeletonDefs.find( idName ) != mSkeletonDefs.end() )
		{
			OGRE_EXCEPT( Exception::ERR_DUPLICATE_ITEM,
						 "Skeleton with name '" + skeletonDef->getName() +"' already exists!",
						 "SkeletonManager::add" );
		}

		mSkeletonDefs[idName] = skeletonDef;
	}
	//-----------------------------------------------------------------------
	void SkeletonManager::remove( const IdString &name )
	{
		SkeletonDefMap::iterator itor = mSkeletonDefs.find( name );
		if( itor == mSkeletonDefs.end() )
		{
			OGRE_EXCEPT( Exception::ERR_ITEM_NOT_FOUND,
						 "Skeleton with name '" + name.getFriendlyText() +"' not found!",
						 "SkeletonManager::remove" );
		}

		mSkeletonDefs.erase( itor );
	}
}
