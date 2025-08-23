#ifndef MANAGEALTMEDIADIALOG_H
#define MANAGEALTMEDIADIALOG_H

//(*Headers(ManageAltMediaDialog)
#include <wx/button.h>
#include <wx/combobox.h>
#include <wx/dialog.h>
#include <wx/sizer.h>
#include <wx/stattext.h>
#include <wx/treectrl.h>
//*)

class ManageAltMediaDialog: public wxDialog
{
    public:

        ManageAltMediaDialog(wxWindow* parent,wxWindowID id=wxID_ANY,const wxPoint& pos=wxDefaultPosition,const wxSize& size=wxDefaultSize);
        virtual ~ManageAltMediaDialog();

        //(*Declarations(ManageAltMediaDialog)
        wxButton* Button_AddMapping;
        wxButton* Button_DeleteMapping;
        wxButton* Button_OK;
        wxComboBox* ComboBox_SelectSequence;
        wxStaticText* StaticText_Sequence;
        wxTreeCtrl* TreeCtrl_AltMediaMappings;
        //*)
    void SetSequences(const wxArrayString& altMediaSequences);

    protected:

        //(*Identifiers(ManageAltMediaDialog)
        static const wxWindowID ID_STATICTEXT_Sequence;
        static const wxWindowID ID_COMBOBOX_SelectSequence;
        static const wxWindowID ID_TREECTRL_AltMediaMappings;
        static const wxWindowID ID_BUTTON_AddMapping;
        static const wxWindowID ID_BUTTON_RemoveMapping;
        static const wxWindowID ID_BUTTON_OK;
        //*)

    private:

        //(*Handlers(ManageAltMediaDialog)
        void OnButton1Click(wxCommandEvent& event);
        void OnComboBox_SequenceSelected(wxCommandEvent& event);
        void OnButton_AddMappingClick(wxCommandEvent& event);
        void OnButton_DeleteMappingClick(wxCommandEvent& event);
        void OnButton_OKClick(wxCommandEvent& event);
        //*)

        DECLARE_EVENT_TABLE()
};

#endif
