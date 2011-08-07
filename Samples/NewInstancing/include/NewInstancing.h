#ifndef __NewInstancing_H__
#define __NewInstancing_H__

#include "SdkSample.h"
#include "OgreInstancedEntity.h"

using namespace Ogre;
using namespace OgreBites;

static const char *c_instancingTechniques[] =
{
	"Shader Based",
	"Vertex Texture Fetch (VTF)",
	"Hardware Instancing Basic",
	"Hardware Instancing + VTF",
	"Limited Animation - Hardware Instancing + VTF",
	"No Instancing"
};

static const char *c_materialsTechniques[] =
{
	"Examples/Instancing/ShaderBased/Robot",
	"Examples/Instancing/VTF/Robot",
	"Examples/Instancing/HWBasic/Robot",
	"Examples/Instancing/VTF/HW/Robot",
	"Examples/Instancing/VTF/HW/LUT/Robot",
	"Examples/Instancing/ShaderBased/Robot"
};

static const char *c_materialsTechniques_dq[] =
{
	"Examples/Instancing/ShaderBased/Robot_dq",
	"Examples/Instancing/VTF/Robot_dq",
	"Examples/Instancing/HWBasic/Robot",
	"Examples/Instancing/VTF/HW/Robot_dq",
	"Examples/Instancing/VTF/HW/LUT/Robot_dq",
	"Examples/Instancing/ShaderBased/Robot_dq"
};

static const char *c_materialsTechniques_dq_two_weights[] =
{
	"Examples/Instancing/ShaderBased/jaiqua_dq_two_weights",
	"Examples/Instancing/VTF/jaiqua_dq_two_weights",
	"Examples/Instancing/HWBasic/jaiqua",
	"Examples/Instancing/VTF/HW/jaiqua_dq_two_weights",
	"Examples/Instancing/VTF/HW/LUT/jaiqua_dq_two_weights",
	"Examples/Instancing/ShaderBased/jaiqua_dq_two_weights"
};

static const char *c_meshNames[] =
{
	"robot.mesh",
	"jaiqua.mesh"
};

#define NUM_TECHNIQUES (((int)InstanceManager::InstancingTechniquesCount) + 1)

class _OgreSampleClassExport Sample_NewInstancing : public SdkSample
{
public:

	Sample_NewInstancing();

	bool frameRenderingQueued(const FrameEvent& evt);

	bool keyPressed(const OIS::KeyEvent& evt);
	

protected:
	void setupContent();

	void setupLighting();
	
	void switchInstancingTechnique();

	void switchSkinningTechnique(int index);

	void createEntities();

	void createInstancedEntities();

	void createSceneNodes();
	
	void clearScene();

	void destroyManagers();

	void cleanupContent();

	void animateUnits( float timeSinceLast );

	void moveUnits( float timeSinceLast );

	//Helper function to look towards normDir, where this vector is normalized, with fixed Yaw
	Quaternion lookAt( const Vector3 &normDir );

	void defragmentBatches();

	void setupGUI();

	void itemSelected(SelectMenu* menu);

	void buttonHit( OgreBites::Button* button );

	void checkBoxToggled(CheckBox* box);

	void sliderMoved(Slider* slider);

	void testCapabilities(const RenderSystemCapabilities* caps);

	//The difference between testCapabilities() is that features checked here aren't fatal errors.
	//which means the sample can run (with limited functionality) on those computers
	void checkHardwareSupport();

	//You can also use a union type to switch between Entity and InstancedEntity almost flawlessly:
	/*
	union FusionEntity
	{
		Entity			entity
		InstancedEntity	instancedEntity;
	};
	*/
	int NUM_INST_ROW;
	int NUM_INST_COLUMN;
	int								mInstancingTechnique;
	int								mCurrentMesh;
	std::vector<MovableObject*>		mEntities;
	std::vector<SceneNode*>			mSceneNodes;
	std::set<AnimationState*>		mAnimations;
	InstanceManager					*mCurrentManager;
	bool							mSupportedTechniques[NUM_TECHNIQUES+1];
	const char**						mCurrentMaterialSet;
	uint16 							mCurrentFlags;

	SelectMenu						*mTechniqueMenu;
	CheckBox						*mMoveInstances;
	CheckBox						*mAnimateInstances;
	SelectMenu						*mSkinningTechniques;
	CheckBox						*mEnableShadows;
	CheckBox						*mSetStatic;
	OgreBites::Button					*mDefragmentBatches;
	CheckBox						*mDefragmentOptimumCull;
	Slider							*mInstancesSlider;
};

#endif
