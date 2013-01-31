/*
 * -----------------------------------------------------------------------------
 * This source file is part of OGRE
 * (Object-oriented Graphics Rendering Engine)
 * For the latest info, see http://www.ogre3d.org/
 *
 * Copyright (c) 2000-2013 Torus Knot Software Ltd
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * -----------------------------------------------------------------------------
 */

#ifndef __QueuedProgressiveMeshGenerator_H_
#define __QueuedProgressiveMeshGenerator_H_

#include "OgreProgressiveMeshGenerator.h"
#include "OgreSingleton.h"
#include "OgreWorkQueue.h"
#include "OgreFrameListener.h"

namespace Ogre
{

/**
 * @brief Request data structure.
 */
struct PMGenRequest {
	struct VertexBuffer {
		size_t vertexCount;
		Vector3* vertexBuffer;
		VertexBuffer() :
			vertexBuffer(0) { }
	};
	struct IndexBuffer {
		size_t indexSize;
		size_t indexCount;
		unsigned char* indexBuffer; // size in bytes = indexSize * indexCount
		IndexBuffer() :
			indexBuffer(0) { }
	};
	struct SubmeshInfo {
		std::vector<IndexBuffer> genIndexBuffers; // order: lodlevel/generated index buffer
		IndexBuffer indexBuffer;
		VertexBuffer vertexBuffer;
		bool useSharedVertexBuffer;
	};
	std::vector<SubmeshInfo> submesh;
	VertexBuffer sharedVertexBuffer;
	LodConfig config;
	std::string meshName;
	~PMGenRequest();
};

/**
 * @brief Processes requests.
 */
class _OgreExport PMWorker :
	private WorkQueue::RequestHandler,
	private ProgressiveMeshGenerator
{
public:
	PMWorker();
	virtual ~PMWorker();
private:
	OGRE_AUTO_MUTEX; // Mutex to force processing one mesh at a time.
	PMGenRequest* mRequest; // This is a copy of the current processed request from stack. This is needed to pass it to overloaded functions like bakeLods().

	WorkQueue::Response* handleRequest(const WorkQueue::Request* req, const WorkQueue* srcQ);
	void buildRequest(LodConfig& lodConfigs);
	void tuneContainerSize();
	void initialize();
	void addVertexBuffer(const PMGenRequest::VertexBuffer& vertexBuffer, bool useSharedVertexLookup);
	void addIndexBuffer(PMGenRequest::IndexBuffer& indexBuffer, bool useSharedVertexLookup, unsigned short submeshID);
	void bakeLods();
};

class _OgreExport PMInjectorListener
{
public:
	PMInjectorListener(){}
	virtual ~PMInjectorListener(){}
	virtual bool shouldInject(PMGenRequest* request){ return true; }
	virtual void injectionCompleted(PMGenRequest* request){}
};

/**
 * @brief Injects the output of a request to the mesh in a thread safe way.
 */
class _OgreExport PMInjector :
	public WorkQueue::ResponseHandler
{
public:
	PMInjector();
	virtual ~PMInjector();

	void handleResponse(const WorkQueue::Response* res, const WorkQueue* srcQ);

	void setInjectorListener(PMInjectorListener* injectorListener) {mInjectorListener = injectorListener;}
	void removeInjectorListener() {mInjectorListener = 0;}
protected:

	// Copies every generated Lod level to the mesh.
	void inject(PMGenRequest* request);

	PMInjectorListener* mInjectorListener;
};

/**
 * @brief Creates a request for the worker. The interface is compatible with ProgressiveMeshGenerator.
 */
class _OgreExport QueuedProgressiveMeshGenerator
{
public:
	void build(LodConfig& lodConfig);
	virtual ~QueuedProgressiveMeshGenerator();
private:
	void copyVertexBuffer(VertexData* data, PMGenRequest::VertexBuffer& out);
	void copyIndexBuffer(IndexData* data, PMGenRequest::IndexBuffer& out);
	void copyBuffers(Mesh* mesh, PMGenRequest* req);
};

}
#endif
