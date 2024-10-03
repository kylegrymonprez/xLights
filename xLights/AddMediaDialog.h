#ifndef ADDMEDIADIALOG_H
#define ADDMEDIADIALOG_H

//(*Headers(AddMediaDialog)
#include <wx/bmpbuttn.h>
#include <wx/button.h>
#include <wx/dialog.h>
#include <wx/sizer.h>
#include <wx/stattext.h>
#include <wx/textctrl.h>
//*)

class AddMediaDialog: public wxDialog
{
    public:

        AddMediaDialog(wxWindow* parent,wxWindowID id=wxID_ANY);
        virtual ~AddMediaDialog();

        //(*Declarations(AddMediaDialog)
        wxBitmapButton* BitmapButton_Xml_Media_File;
        wxButton* Button_Cancel;
        wxButton* Button_Ok;
        wxStaticText* StaticText_FPPHostname;
        wxStaticText* StaticText_MediaFile;
        wxTextCtrl* TextCtrl_FPPHostname;
        wxTextCtrl* TextCtrl_MediaFilePath;
        //*)

    protected:

        //(*Identifiers(AddMediaDialog)
        static const wxWindowID ID_STATICTEXT_FPPHOSTNAME;
        static const wxWindowID ID_TEXTCTRL_FPPHOSTNAME;
        static const wxWindowID ID_STATICTEXT_MEDIAFILE;
        static const wxWindowID ID_TEXTCTRL_MEDIA_PATH;
        static const wxWindowID ID_BITMAPBUTTON_Xml_Media_File;
        static const wxWindowID ID_BUTTON1;
        static const wxWindowID ID_BUTTON2;
        //*)

    private:

        //(*Handlers(AddMediaDialog)
        //*)

        DECLARE_EVENT_TABLE()
};

#endif
