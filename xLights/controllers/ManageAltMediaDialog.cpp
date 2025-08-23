#include "ManageAltMediaDialog.h"

//(*InternalHeaders(ManageAltMediaDialog)
#include <wx/intl.h>
#include <wx/string.h>
//*)

//(*IdInit(ManageAltMediaDialog)
const wxWindowID ManageAltMediaDialog::ID_STATICTEXT_Sequence = wxNewId();
const wxWindowID ManageAltMediaDialog::ID_COMBOBOX_SelectSequence = wxNewId();
const wxWindowID ManageAltMediaDialog::ID_TREECTRL_AltMediaMappings = wxNewId();
const wxWindowID ManageAltMediaDialog::ID_BUTTON_AddMapping = wxNewId();
const wxWindowID ManageAltMediaDialog::ID_BUTTON_RemoveMapping = wxNewId();
const wxWindowID ManageAltMediaDialog::ID_BUTTON_OK = wxNewId();
//*)

BEGIN_EVENT_TABLE(ManageAltMediaDialog,wxDialog)
    //(*EventTable(ManageAltMediaDialog)
    //*)
END_EVENT_TABLE()

ManageAltMediaDialog::ManageAltMediaDialog(wxWindow* parent,wxWindowID id,const wxPoint& pos,const wxSize& size)
{
    //(*Initialize(ManageAltMediaDialog)
    wxFlexGridSizer* FlexGridSizer1;
    wxFlexGridSizer* FlexGridSizer2;
    wxFlexGridSizer* FlexGridSizer3;
    wxFlexGridSizer* FlexGridSizer4;

    Create(parent, id, wxEmptyString, wxDefaultPosition, wxDefaultSize, wxDEFAULT_DIALOG_STYLE, _T("id"));
    SetClientSize(wxDefaultSize);
    Move(wxDefaultPosition);
    FlexGridSizer1 = new wxFlexGridSizer(3, 1, 0, 0);
    FlexGridSizer1->AddGrowableRow(1);
    FlexGridSizer2 = new wxFlexGridSizer(0, 2, 0, 0);
    FlexGridSizer2->AddGrowableCol(1);
    StaticText_Sequence = new wxStaticText(this, ID_STATICTEXT_Sequence, _("Sequence"), wxDefaultPosition, wxDefaultSize, 0, _T("ID_STATICTEXT_Sequence"));
    FlexGridSizer2->Add(StaticText_Sequence, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    ComboBox_SelectSequence = new wxComboBox(this, ID_COMBOBOX_SelectSequence, wxEmptyString, wxDefaultPosition, wxDefaultSize, 0, 0, 0, wxDefaultValidator, _T("ID_COMBOBOX_SelectSequence"));
    FlexGridSizer2->Add(ComboBox_SelectSequence, 1, wxALL|wxEXPAND, 5);
    FlexGridSizer1->Add(FlexGridSizer2, 1, wxALL|wxEXPAND, 5);
    TreeCtrl_AltMediaMappings = new wxTreeCtrl(this, ID_TREECTRL_AltMediaMappings, wxDefaultPosition, wxDefaultSize, wxTR_DEFAULT_STYLE, wxDefaultValidator, _T("ID_TREECTRL_AltMediaMappings"));
    FlexGridSizer1->Add(TreeCtrl_AltMediaMappings, 1, wxALL|wxEXPAND, 5);
    FlexGridSizer3 = new wxFlexGridSizer(0, 2, 0, 0);
    FlexGridSizer3->AddGrowableCol(1);
    FlexGridSizer4 = new wxFlexGridSizer(0, 3, 0, 0);
    Button_AddMapping = new wxButton(this, ID_BUTTON_AddMapping, _("Add"), wxDefaultPosition, wxDefaultSize, 0, wxDefaultValidator, _T("ID_BUTTON_AddMapping"));
    FlexGridSizer4->Add(Button_AddMapping, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    Button_DeleteMapping = new wxButton(this, ID_BUTTON_RemoveMapping, _("Delete"), wxDefaultPosition, wxDefaultSize, 0, wxDefaultValidator, _T("ID_BUTTON_RemoveMapping"));
    FlexGridSizer4->Add(Button_DeleteMapping, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    FlexGridSizer3->Add(FlexGridSizer4, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    Button_OK = new wxButton(this, ID_BUTTON_OK, _("OK"), wxDefaultPosition, wxDefaultSize, 0, wxDefaultValidator, _T("ID_BUTTON_OK"));
    FlexGridSizer3->Add(Button_OK, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    FlexGridSizer1->Add(FlexGridSizer3, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    SetSizer(FlexGridSizer1);
    FlexGridSizer1->SetSizeHints(this);

    Connect(ID_COMBOBOX_SelectSequence, wxEVT_COMMAND_COMBOBOX_SELECTED, (wxObjectEventFunction)&ManageAltMediaDialog::OnComboBox_SequenceSelected);
    //*)
}

ManageAltMediaDialog::~ManageAltMediaDialog()
{
    //(*Destroy(ManageAltMediaDialog)
    //*)
}

void ManageAltMediaDialog::SetSequences(const wxArrayString& sequences)
{
    ComboBox_SelectSequence->Clear();                 // remove old entries
    ComboBox_SelectSequence->Append(sequences);         // add all entries from the array
    ComboBox_SelectSequence->SetSelection(wxNOT_FOUND); // nothing selected by default
    ComboBox_SelectSequence->SetHint("Select Sequence");
}

void ManageAltMediaDialog::OnComboBox_SequenceSelected(wxCommandEvent& event)
{
    //@@@ Load existing mapping from FPP settings if it is there

    //@@@ Clear the mapping content panel
    TreeCtrl_AltMediaMappings->DeleteAllItems();
    wxTreeItemId root = TreeCtrl_AltMediaMappings->AddRoot("Root");
    TreeCtrl_AltMediaMappings->AppendItem(root, "String 1");
    TreeCtrl_AltMediaMappings->AppendItem(root, "String 2");
    TreeCtrl_AltMediaMappings->AppendItem(root, "String 3");
    
}

void ManageAltMediaDialog::OnButton_AddMappingClick(wxCommandEvent& event)
{
    //@@@ New dialog popup that is FPP hostname to Media file from sequence header
}

void ManageAltMediaDialog::OnButton_DeleteMappingClick(wxCommandEvent& event)
{
    ///@@@ Remove from existing FPP settings file
}

void ManageAltMediaDialog::OnButton_OKClick(wxCommandEvent& event)
{
}
