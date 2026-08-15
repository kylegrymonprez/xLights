#pragma once

/***************************************************************
 * This source files comes from the xLights project
 * https://www.xlights.org
 * https://github.com/xLightsSequencer/xLights
 * See the github commit history for a record of contributing
 * developers.
 * Copyright claimed based on commit dates recorded in Github
 * License: https://github.com/xLightsSequencer/xLights/blob/master/License.txt
 **************************************************************/

// Need to do these manually due to issues with wxSmith and wxTreeListCtrl
#include <wx/treelist.h>
#include <wx/treectrl.h>
#include <wx/filename.h>
#include <wx/srchctrl.h>
#include <wx/scrolwin.h>
#include <wx/textctrl.h>

//(*Headers(PixelTestDialog)
#include <wx/button.h>
#include <wx/checkbox.h>
#include <wx/choice.h>
#include <wx/dialog.h>
#include <wx/notebook.h>
#include <wx/panel.h>
#include <wx/radiobut.h>
#include <wx/sizer.h>
#include <wx/slider.h>
#include <wx/splitter.h>
#include <wx/stattext.h>
#include <wx/timer.h>
//*)

#include <glm/glm.hpp>

#include <list>
#include <set>
#include <string>
#include <vector>

#include "shared/utils/xLightsTimer.h"
#include "models/ModelManager.h"
#include "outputs/ChannelTracker.h"
#include "outputs/OutputManager.h"
#include "outputs/TestPatternEngine.h"
#include "outputs/MovingHeadTestEngine.h"
#include "effectpanels/MovingHeadPanels/MHColorWheelPanel.h"
#include "effectpanels/MovingHeadPanels/MovingHeadCanvasPanel.h"

class ModelGroup;
class xLightsFrame;

class ModelTestItem;
class ModelGroupTestItem;
class ModelPreview;
class DmxMovingHeadComm;

class PixelTestDialog: public wxDialog, public IMHColorWheelPanelParent, public IMovingHeadCanvasParent
{
	public:

		PixelTestDialog(xLightsFrame* parent, OutputManager* outputManager, wxFileName networkFile, ModelManager* modelManager, wxWindowID id=wxID_ANY);
		virtual ~PixelTestDialog();
		wxTreeListCtrl* TreeListCtrl_Outputs = nullptr;
		wxTreeListCtrl* TreeListCtrl_ModelGroups = nullptr;
		wxTreeListCtrl* TreeListCtrl_Models = nullptr;
        wxTreeListCtrl* TreeListCtrl_Controllers = nullptr;
        // Live name-filter search boxes, one per tree tab (created manually,
        // outside wxSmith). Typing rebuilds the matching tree filtered to the
        // items whose name (or a descendant's) matches.
        wxSearchCtrl* SearchCtrl_Outputs = nullptr;
        wxSearchCtrl* SearchCtrl_ModelGroups = nullptr;
        wxSearchCtrl* SearchCtrl_Models = nullptr;
        wxSearchCtrl* SearchCtrl_Controllers = nullptr;
        // The "Model" tab uses a dropdown, not a tree; this box filters the
        // dropdown's entries against the full model list below.
        wxSearchCtrl* SearchCtrl_VisualModel = nullptr;
        std::vector<std::string> _visualModelNames;
        wxTimer _filterDebounceTimer;
        wxTreeListCtrl* _pendingFilterTree = nullptr;
        wxFileName _networkFile;
		ModelManager* _modelManager = nullptr;
		bool _cascading = false;
        ModelTestItem* _lastModel = nullptr;
        std::list<ModelTestItem*> _models;
        ChannelTracker _channelTracker;
        std::set<std::string> _uploadedControllers;
        ModelPreview* _modelPreview = nullptr;

        // Pattern maths lives in core so the iPad test surface shares it.
        xltest::TestPatternEngine _testEngine;

        // Moving Head: the fixture is whatever's currently selected on the
        // "Model" tab (Choice_VisualModel/SelectVisualModel) - no separate
        // picker. The controls on the right (Notebook2's Moving Head page)
        // track it via UpdateMHPrimaryFixture(), called from SelectVisualModel
        // whenever that selection changes; when the selected model isn't a
        // moving head, _mhPrimaryFixture is null and the panel reverts to
        // MovingHeadTestEngine::HomeState(nullptr)'s defaults.
        xltest::MovingHeadTestEngine _mhTestEngine;
        DmxMovingHeadComm* _mhPrimaryFixture = nullptr;
        // Color picked on the wheel widget (when shown), cached from
        // NotifyColorUpdated() since MHColorWheelPanel has no plain
        // GetValue()-style accessor.
        xlColor _mhWheelColor = xlWHITE;

        struct MHFeatureControl {
            size_t featureIdx = 0;
            size_t channelIdx = 0;
            bool isChoice = false;
            wxSlider* slider = nullptr;
            wxChoice* choice = nullptr;
            std::vector<int> choiceValues; // parallel to choice's items
        };
        std::vector<MHFeatureControl> _mhFeatureControls;

        // Moving Head controls (Notebook2 page).
        wxPanel* PanelMovingHead = nullptr;
        wxScrolledWindow* MHScroller = nullptr;
        MovingHeadCanvasPanel* MHCanvas_Position = nullptr;
        wxTextCtrl* TextCtrl_MH_Pan = nullptr;
        wxTextCtrl* TextCtrl_MH_Tilt = nullptr;
        // Actual DMX byte (0-255) sent on the motor's coarse channel - not
        // the internal 0-65535 command value degrees maps to. The fine/
        // sub-256 byte a 16-bit motor also sends isn't exposed here, only
        // in real output (Frame() still sends it) - more precision than
        // this panel needs.
        wxTextCtrl* TextCtrl_MH_PanCoarse = nullptr;
        wxTextCtrl* TextCtrl_MH_TiltCoarse = nullptr;
        MHColorWheelPanel* MHPanel_ColorWheel = nullptr;
        wxStaticBoxSizer* StaticBoxSizer_MHColor = nullptr;
        wxSlider* Slider_MH_R = nullptr;
        wxSlider* Slider_MH_G = nullptr;
        wxSlider* Slider_MH_B = nullptr;
        // Shown instead of R/G/B when the fixture's color ability has no
        // real mixing channels (only a white/static channel) - dragging R/G/B
        // to unequal values on such a fixture wouldn't do anything, since
        // DmxColorAbility::SetColorPixels only ever writes the white channel
        // (and only when R=G=B).
        wxSlider* Slider_MH_White = nullptr;
        wxSlider* Slider_MH_Dimmer = nullptr;
        wxButton* Button_MH_ShutterOn = nullptr;
        wxButton* Button_MH_ShutterOff = nullptr;
        wxSlider* Slider_MH_Shutter = nullptr;
        wxPanel* Panel_MH_Features = nullptr;
        wxFlexGridSizer* FlexGridSizer_MH_Features = nullptr;

        // "Raw DMX" section (bottom of the tab): one slider per channel the
        // fixture actually uses, kept in sync both ways with the controls
        // above - see RebuildMHRawDMXGroup()/ApplyRawDMXChannelToControls().
        // Every channel is editable, even ones with no natural higher-level
        // control (fine bytes, non-invertible CMY components, fixed/reserved
        // channels) - those pin a manual override (_mhRawDmxOverride) instead
        // of writing back into some other slider.
        enum class MHRawDmxRole {
            PanCoarse, PanFine, TiltCoarse, TiltFine,
            ColorR, ColorG, ColorB, ColorWhite, ColorCyan, ColorMagenta, ColorYellow, ColorWheel,
            Dimmer, Shutter,
            Feature, FeatureFine,
            Other // unmapped/fixed/preset channel - no natural higher-level control
        };
        struct MHRawDmxChannel {
            MHRawDmxRole role = MHRawDmxRole::Other;
            std::string label;
            size_t featureIdx = 0;
            size_t channelIdx = 0;
            wxSlider* slider = nullptr;
            wxTextCtrl* text = nullptr;
        };
        wxStaticBoxSizer* StaticBoxSizer_MHRawDMX = nullptr;
        std::vector<MHRawDmxChannel> _mhRawDmxChannels; // index = channel - 1 within the fixture
        // Parallel to _mhRawDmxChannels; -1 = no override, else a value
        // pinned onto that channel every frame (applied on top of whatever
        // BuildFrameBytes() would otherwise compute, and pushed onto real
        // output directly since the engine has no notion of these).
        std::vector<int> _mhRawDmxOverride;
        // Guards the per-frame SetValue() refresh from re-entering the
        // sliders' own wxEVT_SLIDER handlers (wx doesn't fire that event from
        // SetValue(), but this costs nothing and removes any doubt).
        bool _mhRawDmxUpdating = false;

        int _twinkleRatio = 0;
		int _chaseGrouping = 0;
		bool _chaseWholeSelection = false;
		bool _checkChannelList = false;
		int _lastNotebookSelection = -1;
		xltest::TestFunction _lastTestFunction = xltest::TestFunction::OFF;
		wxDateTime _starttime;
        wxTreeListItem _rcItem;
        wxTreeListCtrl* _rcTree = nullptr;
        bool m_creating_bound_rect = false;
        int m_bound_start_x = 0;
        int m_bound_start_y = 0;
        int m_bound_end_x = 0;
        int m_bound_end_y = 0;
        int mPointSize = 1;

		//(*Declarations(PixelTestDialog)
		wxButton* Button_Load;
		wxButton* Button_Save;
		wxCheckBox* CheckBox_OutputToLights;
		wxCheckBox* CheckBox_SuppressUnusedOutputs;
		wxCheckBox* CheckBox_Tag50th;
		wxChoice* Choice_VisualModel;
		wxFlexGridSizer* FlexGridSizer_Controllers;
		wxFlexGridSizer* FlexGridSizer_ModelGroups;
		wxFlexGridSizer* FlexGridSizer_Models;
		wxFlexGridSizer* FlexGridSizer_Outputs;
		wxFlexGridSizer* FlexGridSizer_VisualModelSizer;
		wxNotebook* Notebook1;
		wxNotebook* Notebook2;
		wxPanel* Panel1;
		wxPanel* Panel2;
		wxPanel* PanelController;
		wxPanel* PanelRGB;
		wxPanel* PanelRGBCycle;
		wxPanel* PanelStandard;
		wxPanel* Panel_Controllers;
		wxPanel* Panel_Model;
		wxPanel* Panel_ModelGroups;
		wxPanel* Panel_Models;
		wxPanel* Panel_Outputs;
		wxPanel* Panel_VisualModel;
		wxRadioButton* RadioButton_Controller_CyclePorts;
		wxRadioButton* RadioButton_Controller_Off;
		wxRadioButton* RadioButton_Controller_PixelCount;
		wxRadioButton* RadioButton_RGBCycle_ABC;
		wxRadioButton* RadioButton_RGBCycle_ABCAll;
		wxRadioButton* RadioButton_RGBCycle_ABCAllNone;
		wxRadioButton* RadioButton_RGBCycle_MixedColors;
		wxRadioButton* RadioButton_RGBCycle_Off;
		wxRadioButton* RadioButton_RGBCycle_RGBW;
		wxRadioButton* RadioButton_RGB_Alternate;
		wxRadioButton* RadioButton_RGB_Background;
		wxRadioButton* RadioButton_RGB_Chase13;
		wxRadioButton* RadioButton_RGB_Chase14;
		wxRadioButton* RadioButton_RGB_Chase15;
		wxRadioButton* RadioButton_RGB_Chase;
		wxRadioButton* RadioButton_RGB_Off;
		wxRadioButton* RadioButton_RGB_Shimmer;
		wxRadioButton* RadioButton_RGB_Twinkle10;
		wxRadioButton* RadioButton_RGB_Twinkle25;
		wxRadioButton* RadioButton_RGB_Twinkle50;
		wxRadioButton* RadioButton_RGB_Twinkle5;
		wxRadioButton* RadioButton_Standard_Alternate;
		wxRadioButton* RadioButton_Standard_Background;
		wxRadioButton* RadioButton_Standard_Chase13;
		wxRadioButton* RadioButton_Standard_Chase14;
		wxRadioButton* RadioButton_Standard_Chase15;
		wxRadioButton* RadioButton_Standard_Chase;
		wxRadioButton* RadioButton_Standard_Off;
		wxRadioButton* RadioButton_Standard_Shimmer;
		wxRadioButton* RadioButton_Standard_Twinkle10;
		wxRadioButton* RadioButton_Standard_Twinkle25;
		wxRadioButton* RadioButton_Standard_Twinkle50;
		wxRadioButton* RadioButton_Standard_Twinkle5;
		wxSlider* Slider_RGB_BG_B;
		wxSlider* Slider_RGB_BG_G;
		wxSlider* Slider_RGB_BG_R;
		wxSlider* Slider_RGB_H_B;
		wxSlider* Slider_RGB_H_G;
		wxSlider* Slider_RGB_H_R;
		wxSlider* Slider_Speed;
		wxSlider* Slider_Standard_Background;
		wxSlider* Slider_Standard_Highlight;
		wxSplitterWindow* SplitterWindow1;
		wxStaticText* StaticText1;
		wxStaticText* StaticText2;
		wxStaticText* StaticText3;
		wxStaticText* StaticText4;
		wxStaticText* StaticText5;
		wxStaticText* StaticText6;
		wxStaticText* StaticText7;
		wxStaticText* StaticText8;
		wxStaticText* StatusBar1;
		xLightsTimer Timer1;
		//*)

	protected:

		OutputManager* _outputManager = nullptr;
		static const long ID_TREELISTCTRL_Outputs;
		static const long ID_TREELISTCTRL_ModelGroups;
		static const long ID_TREELISTCTRL_Models;
        static const long ID_TREELISTCTRL_Controllers;
        static const long ID_MNU_TEST_SELECTALL;
        static const long ID_MNU_TEST_DESELECTALL;
        static const long ID_MNU_SELECTHIGH;
		static const long ID_MNU_DESELECTHIGH;
        static const long ID_MNU_TEST_SELECTN;
        static const long ID_MNU_TEST_DESELECTN;
        static const long ID_MNU_TEST_NUMBER;
        static const long ID_FILTER_DEBOUNCE;

		//(*Identifiers(PixelTestDialog)
		static const long ID_BUTTON_Load;
		static const long ID_BUTTON_Save;
		static const long ID_PANEL3;
		static const long ID_PANEL6;
		static const long ID_PANEL7;
		static const long ID_STATICTEXT8;
		static const long ID_CHOICE1;
		static const long ID_PANEL11;
		static const long ID_PANEL5;
		static const long ID_PANEL4;
		static const long ID_NOTEBOOK1;
		static const long ID_PANEL1;
		static const long ID_CHECKBOX_OutputToLights;
		static const long ID_CHECKBOX1;
		static const long ID_STATICTEXT2;
		static const long ID_RADIOBUTTON_Standard_Off;
		static const long ID_RADIOBUTTON_Standard_Chase;
		static const long ID_RADIOBUTTON_Standard_Chase13;
		static const long ID_RADIOBUTTON_Standard_Chase14;
		static const long ID_RADIOBUTTON_Standard_Chase15;
		static const long ID_RADIOBUTTON_Standard_Alternate;
		static const long ID_RADIOBUTTON_Standard_Twinke5;
		static const long ID_RADIOBUTTON_Standard_Twinkle10;
		static const long ID_RADIOBUTTON_Standard_Twinkle25;
		static const long ID_RADIOBUTTON_Standard_Twinkle50;
		static const long ID_RADIOBUTTON_Standard_Shimmer;
		static const long ID_RADIOBUTTON_Standard_Background;
		static const long ID_STATICTEXT3;
		static const long ID_SLIDER_Standard_Background;
		static const long ID_STATICTEXT4;
		static const long ID_SLIDER_Standard_Highlight;
		static const long ID_PANEL8;
		static const long ID_STATICTEXT5;
		static const long ID_RADIOBUTTON_RGB_Off;
		static const long ID_RADIOBUTTON_RGB_Chase;
		static const long ID_RADIOBUTTON_RGB_Chase13;
		static const long ID_RADIOBUTTON_RGB_Chase14;
		static const long ID_RADIOBUTTON_RGB_Chase15;
		static const long ID_RADIOBUTTON_RGB_Alternate;
		static const long ID_RADIOBUTTON_RGB_Twinkle5;
		static const long ID_RADIOBUTTON_RGB_Twinkle10;
		static const long ID_RADIOBUTTON_RGB_Twinkle25;
		static const long ID_RADIOBUTTON_RGB_Twinkle50;
		static const long ID_RADIOBUTTON_RGB_Shimmer;
		static const long ID_RADIOBUTTON_RGB_Background;
		static const long ID_SLIDER1;
		static const long ID_SLIDER2;
		static const long ID_SLIDER3;
		static const long ID_SLIDER4;
		static const long ID_SLIDER5;
		static const long ID_SLIDER6;
		static const long ID_PANEL9;
		static const long ID_STATICTEXT6;
		static const long ID_RADIOBUTTON_RGBCycle_Off;
		static const long ID_RADIOBUTTON_RGBCycle_ABC;
		static const long ID_RADIOBUTTON_RGBCycle_ABCAll;
		static const long ID_RADIOBUTTON_RGBCycle_ABCAllNone;
		static const long ID_RADIOBUTTON_RGBCycle_MixedColors;
		static const long ID_RADIOBUTTON_RGBCycle_RGBW;
		static const long ID_CHECKBOX2;
		static const long ID_PANEL10;
		static const long ID_STATICTEXT9;
		static const long ID_RADIOBUTTON_CONTROLLER_OFF;
		static const long ID_RADIOBUTTON_CONTROLLER_CYCLEPORTS;
		static const long ID_RADIOBUTTON_CONTROLLER_PIXELCOUNT;
		static const long ID_PANEL12;
		static const long ID_NOTEBOOK2;
		static const long ID_STATICTEXT1;
		static const long ID_SLIDER_Speed;
		static const long ID_PANEL2;
		static const long ID_SPLITTERWINDOW1;
		static const long ID_STATICTEXT7;
		static const long ID_TIMER1;
		//*)

	private:

		//(*Handlers(PixelTestDialog)
		void OnButton_LoadClick(wxCommandEvent& event);
		void OnButton_SaveClick(wxCommandEvent& event);
		void OnTimer1Trigger(wxTimerEvent& event);
		void OnCheckBox_OutputToLightsClick(wxCommandEvent& event);
		void OnClose(wxCloseEvent& event);
		void OnCheckBox_SuppressUnusedOutputsClick(wxCommandEvent& event);
		void OnNotebook1PageChanged(wxNotebookEvent& event);
		void OnCheckBox_Tag50thClick(wxCommandEvent& event);
		void OnChoice_VisualModelSelect(wxCommandEvent& event);
		//*)

		void OnTreeListCtrlCheckboxtoggled(wxTreeListEvent& event);
        void OnTreeListCtrlItemActivated(wxTreeListEvent& event);
        void OnContextMenu(wxTreeListEvent& event);
        void OnListPopup(wxCommandEvent& event);
        void OnTreeListCtrlItemSelected(wxTreeListEvent& event);
        void OnTreeListCtrlItemExpanding(wxTreeListEvent& event);

		void PopulateOutputTree(OutputManager* outputManager);
		void PopulateModelGroupTree(ModelManager* modelManager);
		void PopulateModelTree(ModelManager* modelManager);

        // Name-filter support. RebuildTree tears down and repopulates a tree
        // (selections live in _channelTracker so they survive), then prunes to
        // the current filter and reveals nested matches.
        void AddTreeFilter(wxPanel* panel, wxFlexGridSizer* sizer, wxSearchCtrl*& ctrl, wxTreeListCtrl* tree);
        wxSearchCtrl* FilterCtrlForTree(wxTreeListCtrl* tree) const;
        void RebuildTree(wxTreeListCtrl* tree);
        bool PruneTree(wxTreeListCtrl* tree, const wxTreeListItem& item, const wxString& filterLower);
        void ExpandFiltered(wxTreeListCtrl* tree, const wxTreeListItem& item);
        void ApplyVisualModelFilter();
        void PopulateVisualModelTree(ModelManager* modelManager);
        void PopulateControllerTree(OutputManager* outputManager, ModelManager* modelManager);
        void SelectVisualModel(const std::string& model);
        void AddChannel(wxTreeListCtrl* tree, wxTreeListItem parent, long absoluteChannel, long relativeChannel, char colour);
        void AddNode(wxTreeListCtrl* tree, wxTreeListItem parent, ModelTestItem* model, long node);
        char GetChannelColour(long ch);
        void AddModelGroup(wxTreeListItem parent, Model* m);
        void AddModelGroup(wxTreeListItem parent, ModelGroupTestItem* m);

		void OnPreviewLeftUp(wxMouseEvent& event);
        void OnPreviewMouseLeave(wxMouseEvent& event);
        void OnPreviewLeftDown(wxMouseEvent& event);
        void OnPreviewLeftDClick(wxMouseEvent& event);
        void OnPreviewMouseMove(wxMouseEvent& event);

		void RenderModel();
        void GetMouseLocation(int x, int y, glm::vec3& ray_origin, glm::vec3& ray_direction);
        void SelectAllInBoundingRect(bool shiftdwn);
        void UpdateVisualModelFromTracker();

        bool AreChannelsAvailable(Model* model);
        bool AreChannelsAvailable(ModelGroup* model);
        void EnsureControllerUploaded(long absoluteChannel);

		void CascadeSelected(wxTreeListCtrl* tree, const wxTreeListItem& item, wxCheckBoxState state);
        void DumpSelected();

		// Detach the two parent-owns-child relationships (ModelTestItem's
		// submodels on the Models tab, ModelGroupTestItem's members on the
		// Model Groups tab) in this subtree so the tree becomes the sole owner
		// and DeleteItem/DeleteAllItems frees every TestItemBase exactly once.
		void ReleaseDualOwnership(wxTreeListCtrl* tree, const wxTreeListItem& item);
		void TeardownTree(wxTreeListCtrl* tree);
		std::list<std::string> GetModelsOnChannels(int start, int end);
		void Clear(wxTreeListCtrl* tree, wxTreeListItem& item);
		std::vector<uint32_t> GetCheckedItems();
		std::vector<uint32_t> GetCheckedItems(char col);
		void OnTimer(long curtime);
		xltest::TestParameters BuildTestParameters(int notebookSelection);
		void TestButtonsOff();
		void RollUpAll(wxTreeListCtrl* tree, wxTreeListItem start);
		void DeactivateNotClickableModels(wxTreeListCtrl* tree);
        void SetTreeTooltip(wxTreeListCtrl* tree, wxTreeListItem& item);
		wxTreeListItem AddController(wxTreeListItem root, Controller* controller);
		void AddOutput(wxTreeListItem root, Output* output);
		std::string SerialiseSettings();
        void DeserialiseSettings(const std::string& settings);
        xltest::TestFunction GetTestFunction(int notebookSelection);
        void SetCheckBoxItemFromTracker(wxTreeListCtrl* tree, wxTreeListItem item, wxCheckBoxState parentState);
        void SetSuspend(bool suspend);

        // Moving Head tab. Built manually outside wxSmith's guarded regions -
        // same convention already used in this file for the search-filter
        // boxes - since its content (fixture abilities, dynamic feature
        // controls) can't be laid out statically.
        void UpdateMHPrimaryFixture(Model* m);

        void BuildMovingHeadTab();
        void RebuildMHColorGroup();
        void RebuildMHFeatureControls();
        xltest::MHTestState BuildMHTestState();
        void NotifyColorUpdated() override;
        void NotifyPositionUpdated() override;
        void UpdateMHPositionText();
        void CommitMHPositionText();
        void CommitMHPositionDMX();
        void RebuildMHRawDMXGroup();
        void ApplyRawDMXChannelToControls(int channelIdx0, uint8_t value);
        // Forwards mouse-wheel events on a control living inside MHScroller
        // to MHScroller itself, so scrolling the tab while the cursor is
        // over e.g. a slider still scrolls the panel instead of the slider
        // consuming the wheel to change its own value.
        void BindMHScrollForward(wxWindow* ctrl);

		DECLARE_EVENT_TABLE()
};

