#ifndef ADDMEDIADIALOG_H
#define ADDMEDIADIALOG_H

//(*Headers(AddMediaDialog)
#include <wx/bmpbuttn.h>
#include <wx/button.h>
#include <wx/checkbox.h>
#include <wx/dialog.h>
#include <wx/sizer.h>
#include <wx/stattext.h>
#include <wx/textctrl.h>
//*)

class AddMediaDialog: public wxDialog
{
    public:

        AddMediaDialog(wxWindow* parent, const std::list<std::string>& media_dirs, wxWindowID id=wxID_ANY);
        virtual ~AddMediaDialog();

        //(*Declarations(AddMediaDialog)
        wxBitmapButton* BitmapButton_Xml_Media_File;
        wxButton* Button_Cancel;
        wxButton* Button_Ok;
        wxCheckBox* CheckBox_UseSquenceMedia;
        wxStaticText* StaticText_FPPHostname;
        wxStaticText* StaticText_MediaFile;
        wxStaticText* StaticText_UseSequenceMedia;
        wxTextCtrl* TextCtrl_FPPHostname;
        wxTextCtrl* TextCtrl_MediaFilePath;
        //*)
        wxString GetFPPHostName() { return TextCtrl_FPPHostname->GetValue(); }
        wxString GetMediaPath() { return TextCtrl_MediaFilePath->GetValue(); }
        bool KeepSequenceName() { return CheckBox_UseSquenceMedia->IsChecked(); }

    protected:

        //(*Identifiers(AddMediaDialog)
        static const wxWindowID ID_STATICTEXT_FPPHOSTNAME;
        static const wxWindowID ID_TEXTCTRL_FPPHOSTNAME;
        static const wxWindowID ID_STATICTEXT_MEDIAFILE;
        static const wxWindowID ID_TEXTCTRL_MEDIA_PATH;
        static const wxWindowID ID_BITMAPBUTTON_Xml_Media_File;
        static const wxWindowID ID_STATICTEXT_USE_SEQ;
        static const wxWindowID ID_CHECKBOX1;
        static const wxWindowID ID_BUTTON1;
        static const wxWindowID ID_BUTTON2;
        //*)

    private:

        //(*Handlers(AddMediaDialog)
        void OnButton_OkClick(wxCommandEvent& event);
        void OnButton_CancelClick(wxCommandEvent& event);
        void OnBitmapButton_MediaFileClick(wxCommandEvent& event);
        //*)
        void MediaChooser();
        const std::list<std::string>& media_directories;

        DECLARE_EVENT_TABLE()
};

#endif
