#ifndef FPPMEDIAMAPDIALOG_H
#define FPPMEDIAMAPDIALOG_H

//(*Headers(FPPMediaMapDialog)
#include <wx/button.h>
#include <wx/choice.h>
#include <wx/dialog.h>
#include <wx/sizer.h>
#include <wx/stattext.h>
//*)

class FPPMediaMapDialog: public wxDialog
{
    public:

        FPPMediaMapDialog(wxWindow* parent,wxWindowID id=wxID_ANY,const wxPoint& pos=wxDefaultPosition,const wxSize& size=wxDefaultSize);
        virtual ~FPPMediaMapDialog();

        //(*Declarations(FPPMediaMapDialog)
        wxButton* Button_Cancel;
        wxButton* Button_OK;
        wxChoice* Choice_AltMedia;
        wxChoice* Choice_FppHostName;
        wxStaticText* StaticText_AltMedia;
        wxStaticText* StaticText_FPPHostname;
        //*)

    protected:

        //(*Identifiers(FPPMediaMapDialog)
        static const wxWindowID ID_STATICTEXT_FPP_HOSTNAME;
        static const wxWindowID ID_CHOICE_FppHostName;
        static const wxWindowID ID_STATICTEXT_AltMedia;
        static const wxWindowID ID_CHOICE_AltMedia;
        static const wxWindowID ID_BUTTON_OK;
        static const wxWindowID ID_BUTTON_Cancel;
        //*)

    private:

        //(*Handlers(FPPMediaMapDialog)
        void OnButton_OKClick(wxCommandEvent& event);
        void OnButton_CancelClick(wxCommandEvent& event);
        //*)

        DECLARE_EVENT_TABLE()
};

#endif
