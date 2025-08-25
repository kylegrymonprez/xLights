#include "FPPMediaMapDialog.h"

//(*InternalHeaders(FPPMediaMapDialog)
#include <wx/intl.h>
#include <wx/string.h>
//*)

//(*IdInit(FPPMediaMapDialog)
const wxWindowID FPPMediaMapDialog::ID_STATICTEXT_FPP_HOSTNAME = wxNewId();
const wxWindowID FPPMediaMapDialog::ID_CHOICE_FppHostName = wxNewId();
const wxWindowID FPPMediaMapDialog::ID_STATICTEXT_AltMedia = wxNewId();
const wxWindowID FPPMediaMapDialog::ID_CHOICE_AltMedia = wxNewId();
const wxWindowID FPPMediaMapDialog::ID_BUTTON_OK = wxNewId();
const wxWindowID FPPMediaMapDialog::ID_BUTTON_Cancel = wxNewId();
//*)

BEGIN_EVENT_TABLE(FPPMediaMapDialog,wxDialog)
    //(*EventTable(FPPMediaMapDialog)
    //*)
END_EVENT_TABLE()

FPPMediaMapDialog::FPPMediaMapDialog(wxWindow* parent,wxWindowID id,const wxPoint& pos,const wxSize& size)
FPPMediaMapDialog::FPPMediaMapDialog(wxWindow* parent, const wxArrayString& hostnames, const std::list<std::string>& altMediaOptions, wxWindowID id,const wxPoint& pos,const wxSize& size)
{
    //(*Initialize(FPPMediaMapDialog)
    wxFlexGridSizer* FlexGridSizer1;
    wxFlexGridSizer* FlexGridSizer2;

    Create(parent, id, wxEmptyString, wxDefaultPosition, wxDefaultSize, wxDEFAULT_DIALOG_STYLE, _T("id"));
    SetClientSize(wxDefaultSize);
    Move(wxDefaultPosition);
    SetMinSize(wxSize(-1,150));
    FlexGridSizer1 = new wxFlexGridSizer(3, 2, 0, 0);
    FlexGridSizer1->AddGrowableCol(1);
    FlexGridSizer1->AddGrowableRow(2);
    StaticText_FPPHostname = new wxStaticText(this, ID_STATICTEXT_FPP_HOSTNAME, _("FPP HostName"), wxDefaultPosition, wxDefaultSize, 0, _T("ID_STATICTEXT_FPP_HOSTNAME"));
    FlexGridSizer1->Add(StaticText_FPPHostname, 1, wxALL|wxALIGN_LEFT|wxALIGN_CENTER_VERTICAL, 5);
    Choice_FppHostName = new wxChoice(this, ID_CHOICE_FppHostName, wxDefaultPosition, wxSize(550,25), 0, 0, 0, wxDefaultValidator, _T("ID_CHOICE_FppHostName"));
    FlexGridSizer1->Add(Choice_FppHostName, 1, wxALL|wxEXPAND, 5);
    StaticText_AltMedia = new wxStaticText(this, ID_STATICTEXT_AltMedia, _("Alternate Media"), wxDefaultPosition, wxDefaultSize, 0, _T("ID_STATICTEXT_AltMedia"));
    FlexGridSizer1->Add(StaticText_AltMedia, 1, wxALL|wxALIGN_LEFT|wxALIGN_CENTER_VERTICAL, 5);
    Choice_AltMedia = new wxChoice(this, ID_CHOICE_AltMedia, wxDefaultPosition, wxSize(550,25), 0, 0, 0, wxDefaultValidator, _T("ID_CHOICE_AltMedia"));
    FlexGridSizer1->Add(Choice_AltMedia, 1, wxALL|wxEXPAND, 5);
    FlexGridSizer1->Add(-1,-1,1, wxALL|wxEXPAND, 5);
    FlexGridSizer2 = new wxFlexGridSizer(1, 0, 0, 0);
    Button_OK = new wxButton(this, ID_BUTTON_OK, _("OK"), wxDefaultPosition, wxDefaultSize, 0, wxDefaultValidator, _T("ID_BUTTON_OK"));
    FlexGridSizer2->Add(Button_OK, 1, wxALL|wxEXPAND, 5);
    Button_Cancel = new wxButton(this, ID_BUTTON_Cancel, _("Cancel"), wxDefaultPosition, wxDefaultSize, 0, wxDefaultValidator, _T("ID_BUTTON_Cancel"));
    FlexGridSizer2->Add(Button_Cancel, 1, wxALL|wxEXPAND, 5);
    FlexGridSizer1->Add(FlexGridSizer2, 1, wxALL|wxEXPAND, 5);
    SetSizer(FlexGridSizer1);
    Fit();

    Connect(ID_CHOICE_FppHostName, wxEVT_COMMAND_CHOICE_SELECTED, (wxObjectEventFunction)&FPPMediaMapDialog::OnChoice_FppHostNameSelect);
    Connect(ID_CHOICE_AltMedia, wxEVT_COMMAND_CHOICE_SELECTED, (wxObjectEventFunction)&FPPMediaMapDialog::OnChoice_AltMediaSelect);
    Connect(ID_BUTTON_OK, wxEVT_COMMAND_BUTTON_CLICKED, (wxObjectEventFunction)&FPPMediaMapDialog::OnButton_OKClick);
    Connect(ID_BUTTON_Cancel, wxEVT_COMMAND_BUTTON_CLICKED, (wxObjectEventFunction)&FPPMediaMapDialog::OnButton_CancelClick);
    //*)
    
    
    
    Button_OK->Disable();

    Choice_FppHostName->Clear();
    Choice_AltMedia->Clear();
    Choice_FppHostName->Append(hostnames);
    for (const auto& entry : altMediaOptions) {
        Choice_AltMedia->Append(entry);
    }

}

FPPMediaMapDialog::~FPPMediaMapDialog()
{
    //(*Destroy(FPPMediaMapDialog)
    //*)
}


void FPPMediaMapDialog::OnButton_OKClick(wxCommandEvent& event)
{

}

void FPPMediaMapDialog::OnButton_CancelClick(wxCommandEvent& event)
{
    EndDialog(wxID_OK);
}

void FPPMediaMapDialog::OnChoice_FppHostNameSelect(wxCommandEvent& event)
{
    int sel = event.GetSelection();     // the selected index (-1 if none)
    wxString value = event.GetString(); // the actual string

    if (sel != wxNOT_FOUND) {
        m_selectedHostName = value;
    }

    CheckEnableOKButton();
}


void FPPMediaMapDialog::OnChoice_AltMediaSelect(wxCommandEvent& event)
{
    int sel = event.GetSelection();     // the selected index (-1 if none)
    wxString value = event.GetString(); // the actual string

    if (sel != wxNOT_FOUND) {
        m_selectedAltMedia = value;
    }

    CheckEnableOKButton();
}

void FPPMediaMapDialog::CheckEnableOKButton()
{
    if ( !m_selectedAltMedia.IsEmpty() && !m_selectedHostName.IsEmpty() )
        Button_OK->Enable();
    else
        Button_OK->Disable();
}

void FPPMediaMapDialog::PopulateChoiceOptions()
{
    
}
