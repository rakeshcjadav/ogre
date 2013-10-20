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
#ifndef __SSE2_ArraySphere_H__
#define __SSE2_ArraySphere_H__

#ifndef __ArraySphere_H__
	#error "Don't include this file directly. include Math/Array/OgreArraySphere.h"
#endif

#include "OgreSphere.h"

#include "Math/Array/OgreMathlib.h"
#include "Math/Array/OgreArrayVector3.h"

namespace Ogre
{
	/** \addtogroup Core
	*  @{
	*/
	/** \addtogroup Math
	*  @{
	*/
	/** Cache-friendly array of Sphere represented as a SoA array.
        @remarks
            ArraySphere is a SIMD & cache-friendly version of Sphere.
			@See ArrayVector3 for more information.
		@par
			Extracting one sphere needs 64 bytes, which is within
			the 64 byte size of common cache lines.
			Architectures where the cache line == 32 bytes may want to
			set ARRAY_PACKED_REALS = 2 depending on their needs
    */
    class _OgreExport ArraySphere
    {
    public:
		ArrayReal			m_radius;
		ArrayVector3		m_center;

		ArraySphere()
		{
		}

		ArraySphere( const ArrayReal &radius, const ArrayVector3 &center ) :
					m_radius( radius ),
					m_center( center )
		{
		}

		void getAsSphere( Sphere &out, size_t index ) const
		{
			//Be careful of not writing to these regions or else strict aliasing rule gets broken!!!
			const Real *aliasedRadius = reinterpret_cast<const Real*>( &m_radius );

			Vector3 center;
			m_center.getAsVector3( center, index );
			out.setCenter( center );
			out.setRadius( *aliasedRadius );
		}

		/// Prefer using @see getAsSphere() because this function may have more
		/// overhead (the other one is faster)
		Sphere getAsSphere( size_t index ) const
		{
			Sphere retVal;
			getAsSphere( retVal, index );
			return retVal;
		}

		void setFromSphere( const Sphere &sphere, size_t index )
		{
			Real *aliasedRadius = reinterpret_cast<Real*>( &m_radius );
			aliasedRadius[index] = sphere.getRadius();
			m_center.setFromVector3( sphere.getCenter(), index );
		}

		/// Sets all packed spheres to the same value as the scalar input sphere
		void setAll( const Sphere &sphere )
		{
			const Real fRadius		= sphere.getRadius();
			const Vector3 &center	= sphere.getCenter();
			m_radius = _mm_set_ps1( fRadius );
			m_center.m_chunkBase[0] = _mm_set_ps1( center.x );
			m_center.m_chunkBase[1] = _mm_set_ps1( center.y );
			m_center.m_chunkBase[2] = _mm_set_ps1( center.z );
		}

		/// @copydoc Sphere::intersects()
		inline ArrayReal intersects( const ArraySphere &s ) const;

		/// @copydoc Sphere::intersects()
		inline ArrayReal intersects( const ArrayAabb &aabb ) const;

		/// @copydoc Sphere::intersects()
		inline ArrayReal intersects( const ArrayVector3 &v ) const;
    };
	/** @} */
	/** @} */

}

#include "OgreArraySphere.inl"

#endif
