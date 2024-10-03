#include "AddMediaDialog.h"

//(*InternalHeaders(AddMediaDialog)
#include <wx/bitmap.h>
#include <wx/image.h>
#include <wx/intl.h>
#include <wx/string.h>
//*)

//(*IdInit(AddMediaDialog)
const wxWindowID AddMediaDialog::ID_STATICTEXT_FPPHOSTNAME = wxNewId();
const wxWindowID AddMediaDialog::ID_TEXTCTRL_FPPHOSTNAME = wxNewId();
const wxWindowID AddMediaDialog::ID_STATICTEXT_MEDIAFILE = wxNewId();
const wxWindowID AddMediaDialog::ID_TEXTCTRL_MEDIA_PATH = wxNewId();
const wxWindowID AddMediaDialog::ID_BITMAPBUTTON_Xml_Media_File = wxNewId();
const wxWindowID AddMediaDialog::ID_STATICTEXT_FNBEHAVIOR = wxNewId();
const wxWindowID AddMediaDialog::ID_COMBOBOX1 = wxNewId();
const wxWindowID AddMediaDialog::ID_BUTTON1 = wxNewId();
const wxWindowID AddMediaDialog::ID_BUTTON2 = wxNewId();
//*)

BEGIN_EVENT_TABLE(AddMediaDialog,wxDialog)
    //(*EventTable(AddMediaDialog)
    //*)
END_EVENT_TABLE()

AddMediaDialog::AddMediaDialog(wxWindow* parent,wxWindowID id)
{
    //(*Initialize(AddMediaDialog)
    wxBoxSizer* BoxSizer1;
    wxFlexGridSizer* FlexGridSizer1;

    Create(parent, wxID_ANY, wxEmptyString, wxDefaultPosition, wxDefaultSize, wxDEFAULT_DIALOG_STYLE, _T("wxID_ANY"));
    FlexGridSizer1 = new wxFlexGridSizer(0, 3, 0, 0);
    FlexGridSizer1->AddGrowableCol(1);
    StaticText_FPPHostname = new wxStaticText(this, ID_STATICTEXT_FPPHOSTNAME, _("FPP Hostname:"), wxDefaultPosition, wxDefaultSize, 0, _T("ID_STATICTEXT_FPPHOSTNAME"));
    FlexGridSizer1->Add(StaticText_FPPHostname, 1, wxALL|wxALIGN_LEFT|wxALIGN_CENTER_VERTICAL, 5);
    TextCtrl_FPPHostname = new wxTextCtrl(this, ID_TEXTCTRL_FPPHOSTNAME, wxEmptyString, wxDefaultPosition, wxDefaultSize, 0, wxDefaultValidator, _T("ID_TEXTCTRL_FPPHOSTNAME"));
    TextCtrl_FPPHostname->SetMaxLength(15);
    FlexGridSizer1->Add(TextCtrl_FPPHostname, 1, wxALL|wxEXPAND, 5);
    FlexGridSizer1->Add(10,8,1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    StaticText_MediaFile = new wxStaticText(this, ID_STATICTEXT_MEDIAFILE, _("Media File:"), wxDefaultPosition, wxDefaultSize, 0, _T("ID_STATICTEXT_MEDIAFILE"));
    FlexGridSizer1->Add(StaticText_MediaFile, 1, wxALL|wxALIGN_LEFT|wxALIGN_CENTER_VERTICAL, 5);
    TextCtrl_MediaFilePath = new wxTextCtrl(this, ID_TEXTCTRL_MEDIA_PATH, wxEmptyString, wxDefaultPosition, wxDefaultSize, 0, wxDefaultValidator, _T("ID_TEXTCTRL_MEDIA_PATH"));
    TextCtrl_MediaFilePath->SetMaxLength(15);
    FlexGridSizer1->Add(TextCtrl_MediaFilePath, 1, wxALL|wxEXPAND, 5);
    BitmapButton_Xml_Media_File = new wxBitmapButton(this, ID_BITMAPBUTTON_Xml_Media_File, wxArtProvider::GetBitmapBundle("wxART_CDROM",wxART_BUTTON), wxDefaultPosition, wxDefaultSize, wxBU_AUTODRAW, wxDefaultValidator, _T("ID_BITMAPBUTTON_Xml_Media_File"));
    FlexGridSizer1->Add(BitmapButton_Xml_Media_File, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    StaticText_FileRenameBehavior = new wxStaticText(this, ID_STATICTEXT_FNBEHAVIOR, _("Filename Behavior:"), wxDefaultPosition, wxDefaultSize, 0, _T("ID_STATICTEXT_FNBEHAVIOR"));
    FlexGridSizer1->Add(StaticText_FileRenameBehavior, 1, wxALL|wxALIGN_LEFT|wxALIGN_CENTER_VERTICAL, 5);
    ComboBox1 = new wxComboBox(this, ID_COMBOBOX1, wxEmptyString, wxDefaultPosition, wxDefaultSize, 0, 0, 0, wxDefaultValidator, _T("ID_COMBOBOX1"));
    ComboBox1->Append(_("Sequence Name"));
    ComboBox1->Append(_("Don\'t Rename"));
    FlexGridSizer1->Add(ComboBox1, 1, wxALL|wxEXPAND, 5);
    FlexGridSizer1->Add(-1,-1,1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    FlexGridSizer1->Add(0,0,1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    BoxSizer1 = new wxBoxSizer(wxHORIZONTAL);
    Button_Ok = new wxButton(this, ID_BUTTON1, _("Ok"), wxDefaultPosition, wxDefaultSize, 0, wxDefaultValidator, _T("ID_BUTTON1"));
    Button_Ok->SetDefault();
    BoxSizer1->Add(Button_Ok, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    Button_Cancel = new wxButton(this, ID_BUTTON2, _("Cancel"), wxDefaultPosition, wxDefaultSize, 0, wxDefaultValidator, _T("ID_BUTTON2"));
    BoxSizer1->Add(Button_Cancel, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    FlexGridSizer1->Add(BoxSizer1, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
    SetSizer(FlexGridSizer1);
    FlexGridSizer1->SetSizeHints(this);

    Connect(ID_BITMAPBUTTON_Xml_Media_File, wxEVT_COMMAND_BUTTON_CLICKED, (wxObjectEventFunction)&AddMediaDialog::OnBitmapButton_MediaFileClick);
    Connect(ID_BUTTON1, wxEVT_COMMAND_BUTTON_CLICKED, (wxObjectEventFunction)&AddMediaDialog::OnButton_OkClick);
    Connect(ID_BUTTON2, wxEVT_COMMAND_BUTTON_CLICKED, (wxObjectEventFunction)&AddMediaDialog::OnButton_CancelClick);
    //*)
}

AddMediaDialog::~AddMediaDialog()
{
    //(*Destroy(AddMediaDialog)
    //*)
}


void AddMediaDialog::OnButton_OkClick(wxCommandEvent& event)
{
}

void AddMediaDialog::OnButton_CancelClick(wxCommandEvent& event)
{
}

void AddMediaDialog::OnBitmapButton_MediaFileClick(wxCommandEvent& event)
{
}
