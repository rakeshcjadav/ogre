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
-----------------------------------------------------------------------------
*/
#include "PlayPenTests.h"

PlayPen_MaterialSchemesWithMismatchedLOD::PlayPen_MaterialSchemesWithMismatchedLOD()
{
	mInfo["Title"] = "PlayPen_MaterialSchemesWithMismatchedLOD";
	mInfo["Description"] = "Tests.";
	addScreenshotFrame(250);
}
//----------------------------------------------------------------------------

void PlayPen_MaterialSchemesWithMismatchedLOD::setupContent()
{
	
	Entity *ent = mSceneMgr->createEntity("robot", "robot.mesh");
	mSceneMgr->getRootSceneNode()->createChildSceneNode()->attachObject(ent);
	mSceneMgr->setAmbientLight(ColourValue(0.8, 0.8, 0.8));
	
	MaterialPtr mat = MaterialManager::getSingleton().create("schemetest", 
	TRANSIENT_RESOURCE_GROUP);
	// default scheme
	mat->getTechnique(0)->getPass(0)->createTextureUnitState("GreenSkin.jpg");
	
	// LOD 0, newscheme 
	Technique* t = mat->createTechnique();
	t->setSchemeName("newscheme");
	t->createPass()->createTextureUnitState("rockwall.tga");
	ent->setMaterialName("schemetest");
	
	// LOD 1, default
	t = mat->createTechnique();
	t->setLodIndex(1);
	t->createPass()->createTextureUnitState("Water02.jpg");
	
	// LOD 2, default
	t = mat->createTechnique();
	t->setLodIndex(2);
	t->createPass()->createTextureUnitState("clouds.jpg");
	
	// LOD 1, newscheme
	t = mat->createTechnique();
	t->setLodIndex(1);
	t->createPass()->createTextureUnitState("r2skin.jpg");
	t->setSchemeName("newscheme");
	
	// No LOD 2 for newscheme! Should fallback on LOD 1
	
	Material::LodValueList ldl;
	//ldl.push_back(Math::Sqr(250.0f));
	//ldl.push_back(Math::Sqr(500.0f));
	ldl.push_back(150.0f);
	ldl.push_back(300.0f);
	mat->setLodLevels(ldl);
	
	
	ent->setMaterialName("schemetest");
	
	// create a second viewport using alternate scheme
	Viewport* vp = mWindow->addViewport(mCamera, 1, 0.75, 0, 0.25, 0.25);
	vp->setMaterialScheme("newscheme");
	vp->setOverlaysEnabled(false);

	mCamera->setPosition(0,90,350);
}
