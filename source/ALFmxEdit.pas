unit ALFmxEdit;

interface

{$IF defined(MACOS) and not defined(IOS)}
  {$DEFINE _MACOS}
{$ENDIF}

uses System.Types,
     system.Classes,
     System.UITypes,
     {$IF defined(android)}
     System.Messaging,
     Androidapi.JNI.GraphicsContentViewText,
     Androidapi.JNIBridge,
     Androidapi.JNI.Widget,
     Androidapi.JNI.JavaTypes,
     ALAndroidApi,
     {$ELSEIF defined(IOS)}
     System.TypInfo,
     iOSapi.Foundation,
     iOSapi.UIKit,
     Macapi.ObjectiveC,
     Macapi.ObjCRuntime,
     ALIosNativeControl,
     {$ELSE}
     FMX.Edit,
     {$ENDIF}
     FMX.types,
     Fmx.Graphics,
     Fmx.controls,
     ALFmxObjects;

Type

  {**********************************}
  TALAutoCapitalizationType = (acNone, // Specifies that there is no automatic text capitalization.
                               acWords, // Specifies automatic capitalization of the first letter of each word.
                               acSentences, // Specifies automatic capitalization of the first letter of each sentence.
                               acAllCharacters); // Specifies automatic capitalization of all characters, such as for entry of two-character state abbreviations for the United States.


{$REGION ' ANDROID'}
{$IF defined(android)}
type

  {*********************}
  TALAndroidEdit = class;

  {****************************************************************}
  // the design of the androidText can be done in the res/styles.xml
  // please see the example of the demos\AlFmxcontrols.dproj
  //
  // know bug: it's not really a bug, but if you show several edit on the form
  //           then all these edits are in their own window. the problem on android
  //           is that the window system management doesn't permit to change the
  //           z-order of the popup windows with same type. i look in the source code, and if we can
  //           access com.android.server.wm.WindowManagerService then it's could be easy
  //           because Z-order is just defined by the order of some internal list of WindowState (ie WindowList)
  //           (see addAppWindowToListLocked for example). as a workaround the only solution
  //           i found was to remove the window from the app and then add it again (because
  //           last added window is always on the top). but this cause little nasty effect because
  //           the edit is visually hidden to be latter visually show again .. we will say it's a
  //           click effect ;) we need the z-order because of the keyword suggestion popup windows that
  //           could be behind other edit
  //           https://stackoverflow.com/questions/44231597/how-to-change-the-z-order-of-window-added-via-windowmanager
  //
  // NOTE: it's seam that callinUIThread are called sequentially, so in setter i don't need to wait for finishing
  //       but under Tokyo this is not anymore important as callinUIThread is deprecated
  //
  // procedure TForm1.Button1Click(Sender: TObject);
  // var i, j, k: integer;
  // begin
  //
  //   j := 0;
  //   for I := 0 to 10 do begin
  //     CallinUiThread(
  //       procedure
  //         begin
  //           sleep(1000);
  //           AtomicIncrement(j);
  //         end);
  //   end;
  //
  //   CallInUIThreadAndWaitFinishing(
  //     procedure
  //       Begin
  //         K := J;
  //       end);
  //
  //   Showmessage(inttostr(k));
  //
  // end;
  //
  // => it's will return me 11 ! so everything is fine
  TALAndroidEdit = class(TControl)
  private

    type

      {~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
      TALTextWatcher = class(TJavaLocal, JTextWatcher)
      private
        [Weak] FEditControl: TALAndroidEdit;
      public
        constructor Create(const aEditcontrol: TALAndroidEdit);
        procedure afterTextChanged(s: JEditable); cdecl;
        procedure beforeTextChanged(s: JCharSequence; start: Integer; count: Integer; after: Integer); cdecl;
        procedure onTextChanged(s: JCharSequence; start: Integer; before: Integer; count: Integer); cdecl;
      end;

      {~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
      TALEditorActionListener = class(TJavaLocal, JTextView_OnEditorActionListener)
      private
        fIsMultiLineEditControl: Boolean;
        [Weak] FEditControl: TALAndroidEdit;
      public
        constructor Create(const aEditcontrol: TALAndroidEdit);
        function onEditorAction(v: JTextView; actionId: Integer; event: JKeyEvent): Boolean; cdecl;
      end;

      {~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
      TALFocusChangeListener = class(TJavaLocal, JView_OnFocusChangeListener)
      private
        [Weak] FEditControl: TALAndroidEdit;
      public
        constructor Create(const aEditcontrol: TALAndroidEdit);
        procedure onFocusChange(v: JView; hasFocus: Boolean); cdecl;
      end;

      {~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
      TALSoftInputListener = class(TJavaLocal, JALSoftInputListener)
      private
        [Weak] FEditControl: TALAndroidEdit;
      public
        constructor Create(const aEditcontrol: TALAndroidEdit);
        procedure onSoftInputShown; cdecl;
        procedure onSoftInputHidden; cdecl;
      end;

      {~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
      TALKeyPreImeListener = class(TJavaLocal, JALKeyPreImeListener)
      private
        [Weak] FEditControl: TALAndroidEdit;
      public
        constructor Create(const aEditcontrol: TALAndroidEdit);
        function onKeyPreIme(keyCode: Integer; event: JKeyEvent): Boolean; cdecl;
      end;

  private
    FNativeViewAttached: Boolean;
    FEditText: JALEditText;
    FLayout: JALControlHostLayout;
    FTextWatcher: TALTextWatcher;
    FEditorActionListener: TALEditorActionListener;
    FSoftInputListener: TALSoftInputListener;
    FKeyPreImeListener: TALKeyPreImeListener;
    FFocusChangeListener: TALFocusChangeListener;
    fTextPrompt: String;
    FPadding: TBounds;
    fOnChangeTracking: TNotifyEvent;
    fOnReturnKey: TNotifyEvent;
    FScreenScale: single;
    fFormActivateMessageID: integer;
    fFormDeactivateMessageID: integer;
    fApplicationEventMessageID: integer;
    fReturnKeyType: TReturnKeyType;
    fKeyboardType: TVirtualKeyboardType;
    fPassword: boolean;
    FTextSettings: TTextSettings;
    fHideSoftInputOnExit: Boolean;
    fIsMultiline: Boolean;
    fMaxLength: integer;
    procedure DoSetInputType(const aEditText: JALEditText;
                             const aKeyboardType: TVirtualKeyboardType;
                             const aPassword: Boolean;
                             const aIsMultiline: Boolean);
    procedure setKeyboardType(const Value: TVirtualKeyboardType);
    function GetKeyboardType: TVirtualKeyboardType;
    procedure setPassword(const Value: Boolean);
    function GetPassword: Boolean;
    procedure setCheckSpelling(const Value: Boolean);
    function GetCheckSpelling: Boolean;
    procedure DoSetReturnKeyType(const aEditText: JALEditText; const aReturnKeyType: TReturnKeyType);
    procedure setReturnKeyType(const Value: TReturnKeyType);
    function GetReturnKeyType: TReturnKeyType;
    function GetTextPrompt: String;
    procedure setTextPrompt(const Value: String);
    function GetTextPromptColor: TAlphaColor;
    procedure setTextPromptColor(const Value: TAlphaColor);
    function GetTextSettings: TTextSettings;
    procedure SetTextSettings(const Value: TTextSettings);
    function getText: String;
    procedure SetText(const Value: String);
    function GetLineSpacingMultiplier: single;
    procedure SetLineSpacingMultiplier(const Value: single);
    function GetLineSpacingExtra: single;
    procedure SetLineSpacingExtra(const Value: single);
    procedure SetPadding(const Value: TBounds);
    function GetPadding: TBounds;
    procedure SetMaxLength(const Value: integer);
    function GetMaxLength: integer;
    procedure OnFontChanged(Sender: TObject);
    procedure FormActivateHandler(const Sender: TObject; const M: TMessage);
    procedure FormDeactivateHandler(const Sender: TObject; const M: TMessage);
    procedure ApplicationEventHandler(const Sender: TObject; const M : TMessage);
    function GetEditText: JALEditText;
  protected
    procedure requestFocus;
    procedure DoEndUpdate; override;
    procedure AncestorVisibleChanged(const Visible: Boolean); override;
    procedure AncestorParentChanged; override;
    procedure ParentChanged; override;
    procedure DoAbsoluteChanged; override;
    procedure Resize; override;
    procedure VisibleChanged; override;
    procedure ChangeOrder; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure realignContent(const aForce: boolean = False); virtual;
    property HideSoftInputOnExit: boolean read fHideSoftInputOnExit write fHideSoftInputOnExit;
  public
    constructor Create(const AOwner: TComponent; Const aIsMultiline: Boolean = False; const aDefStyleAttr: String = ''); reintroduce; virtual;
    destructor Destroy; override;
    procedure RecalcOpacity; override;
    Procedure AddNativeView;
    Procedure RemoveNativeView;
    Procedure setSelection(const aStart: integer; const aStop: Integer); overload;
    Procedure setSelection(const aindex: integer); overload;
    function getLineHeight: Single; // << it's include the line spacing
    function getLineCount: integer;
    property OnChangeTracking: TNotifyEvent read fOnChangeTracking write fOnChangeTracking;
    property OnReturnKey: TNotifyEvent read fOnReturnKey write fOnReturnKey;
    property ReturnKeyType: TReturnKeyType read GetReturnKeyType write SetReturnKeyType default TReturnKeyType.Default;
    property KeyboardType: TVirtualKeyboardType read GetKeyboardType write SetKeyboardType default TVirtualKeyboardType.Default;
    property Password: Boolean read GetPassword write SetPassword default False;
    property TextPrompt: String read GetTextPrompt write setTextPrompt;
    property TextPromptColor: TAlphaColor read GetTextPromptColor write setTextPromptColor; // << null mean use the default color
    property MaxLength: integer read GetMaxLength write SetMaxLength default 0;
    property Text: String read getText write SetText;
    property TextSettings: TTextSettings read GetTextSettings write SetTextSettings;
    property CheckSpelling: Boolean read GetCheckSpelling write SetCheckSpelling default true;
    property LineSpacingMultiplier: single read GetLineSpacingMultiplier write SetLineSpacingMultiplier; // <<  Each line will have its height multiplied by LineSpacingMultiplier
    property LineSpacingExtra: single read GetLineSpacingExtra write SetLineSpacingExtra; // <<  Each line will have its height added by LineSpacingExtra
    property EditText: JALEditText read GetEditText;
    property Padding: TBounds read GetPadding write SetPadding;
  end;
{$endif}
{$ENDREGION}

{$REGION ' IOS'}
{$IF defined(ios)}
type

  {*************************************}
  IALUITextField = interface(UITextField)
    ['{E4E67240-F15A-444F-8CE1-A3A830C023E8}']
    procedure touchesBegan(touches: NSSet; withEvent: UIEvent); cdecl;
    procedure touchesCancelled(touches: NSSet; withEvent: UIEvent); cdecl;
    procedure touchesEnded(touches: NSSet; withEvent: UIEvent); cdecl;
    procedure touchesMoved(touches: NSSet; withEvent: UIEvent); cdecl;
    procedure ControlEventEditingChanged; cdecl;
    procedure ControlEventEditingDidEnd; cdecl;
    function canBecomeFirstResponder: Boolean; cdecl;
    function canPerformAction(action: SEL; withSender: Pointer): Boolean; cdecl;
  end;

  {******************************}
  TALIosTextFieldDelegate = class;
  TALIosEdit = class;

  {******************************************}
  TALIosTextField = class(TALIosNativeControl)
  private
    [Weak] FEditControl: TALIosEdit;
    FTextFieldDelegate: TALIosTextFieldDelegate;
    function GetView: UITextField;
  protected
    function GetObjectiveCClass: PTypeInfo; override;
  public
    constructor Create; overload; override;
    constructor Create(const AControl: TControl); overload; override;
    destructor Destroy; override;
    procedure ControlEventEditingChanged; cdecl;
    procedure ControlEventEditingDidEnd; cdecl;
    function canPerformAction(action: SEL; withSender: Pointer): Boolean; cdecl;
    function canBecomeFirstResponder: Boolean; cdecl;
    property View: UITextField read GetView;
  end;

  {************************************************************}
  TALIosTextFieldDelegate = class(TOCLocal, UITextFieldDelegate)
  private
    [Weak] FTextField: TALIosTextField;
  public
    constructor Create(const ATextField: TALIosTextField);
    function textField(textField: UITextField; shouldChangeCharactersInRange: NSRange; replacementString: NSString): Boolean; cdecl; // << this work even without [MethodName('textField:shouldChangeCharactersInRange:replacementString:')] - better name would be textFieldShouldChangeCharactersInRange but i prefer to keep the name given by Delphi
    procedure textFieldDidBeginEditing(textField: UITextField); cdecl;
    procedure textFieldDidEndEditing(textField: UITextField); cdecl;
    function textFieldShouldBeginEditing(textField: UITextField): Boolean; cdecl;
    function textFieldShouldClear(textField: UITextField): Boolean; cdecl;
    function textFieldShouldEndEditing(textField: UITextField): Boolean; cdecl;
    function textFieldShouldReturn(textField: UITextField): Boolean; cdecl;
  end;

  {**************************}
  TALIosEdit = class(TControl)
  private
    FTextField: TALIosTextField;
    fTextPromptColor: TalphaColor;
    fOnChangeTracking: TNotifyEvent;
    fOnReturnKey: TNotifyEvent;
    FTextSettings: TTextSettings;
    fMaxLength: integer;
    procedure setKeyboardType(const Value: TVirtualKeyboardType);
    function GetKeyboardType: TVirtualKeyboardType;
    procedure setAutoCapitalizationType(const Value: TALAutoCapitalizationType);
    function GetAutoCapitalizationType: TALAutoCapitalizationType;
    procedure setPassword(const Value: Boolean);
    function GetPassword: Boolean;
    procedure setCheckSpelling(const Value: Boolean);
    function GetCheckSpelling: Boolean;
    procedure setReturnKeyType(const Value: TReturnKeyType);
    function GetReturnKeyType: TReturnKeyType;
    function GetTextPrompt: String;
    procedure setTextPrompt(const Value: String);
    function GetTextPromptColor: TAlphaColor;
    procedure setTextPromptColor(const Value: TAlphaColor);
    procedure applyTextPromptWithColor(const aStr: String; const aColor: TAlphaColor);
    function GetTintColor: TAlphaColor;
    procedure setTintColor(const Value: TAlphaColor);
    function GetTextSettings: TTextSettings;
    procedure SetTextSettings(const Value: TTextSettings);
    function getText: String;
    procedure SetText(const Value: String);
    procedure DoFontChanged;
    procedure OnFontChanged(Sender: TObject);
  protected
    procedure AncestorVisibleChanged(const Visible: Boolean); override;
    procedure AncestorParentChanged; override;
    procedure ParentChanged; override;
    procedure ClipChildrenChanged; override;
    procedure DoAbsoluteChanged; override;
    procedure DoRootChanged; override;
    procedure Resize; override;
    procedure VisibleChanged; override;
    procedure ChangeOrder; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure DoEndUpdate; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RecalcOpacity; override;
    procedure RecalcEnabled; override;
    Procedure AddNativeView;
    Procedure RemoveNativeView;
    function PointInObjectLocal(X: Single; Y: Single): Boolean; override;
    property OnChangeTracking: TNotifyEvent read fOnChangeTracking write fOnChangeTracking;
    property OnReturnKey: TNotifyEvent read fOnReturnKey write fOnReturnKey;
    property ReturnKeyType: TReturnKeyType read GetReturnKeyType write SetReturnKeyType;
    property KeyboardType: TVirtualKeyboardType read GetKeyboardType write SetKeyboardType;
    property AutoCapitalizationType: TALAutoCapitalizationType read GetAutoCapitalizationType write SetAutoCapitalizationType;
    property Password: Boolean read GetPassword write SetPassword default False;
    property TextPrompt: String read GetTextPrompt write setTextPrompt;
    property TextPromptColor: TAlphaColor read GetTextPromptColor write setTextPromptColor default TalphaColorRec.null; // << null mean use the default color
    property TintColor: TAlphaColor read GetTintColor write setTintColor; // << null mean use the default color
    property MaxLength: integer read fMaxLength write fMaxLength default 0;
    property Text: String read getText write SetText;
    property TextSettings: TTextSettings read GetTextSettings write SetTextSettings;
    property CheckSpelling: Boolean read GetCheckSpelling write SetCheckSpelling default true;
    property TextField: TALIosTextField read FTextField;
  end;

{$endif}
{$ENDREGION}

type

  {***************************}
  TALEdit = class(TALRectangle)
  private
    fDefStyleAttr: String;
    FAutoTranslate: Boolean;
    FAutoConvertFontFamily: boolean;
    fOnChangeTracking: TNotifyEvent;
    fOnReturnKey: TNotifyEvent;
    fOnEnter: TNotifyEvent;
    fOnExit: TNotifyEvent;
    FTextSettings: TTextSettings;
    {$IF defined(android)}
    fTintColor: TalphaColor;
    fAutoCapitalizationType: TALAutoCapitalizationType;
    fEditControl: TALAndroidEdit;
    function GetAndroidEditText: JALEditText;
    {$ELSEIF defined(IOS)}
    fEditControl: TALIosEdit;
    function GetIosTextField: TALIosTextField;
    {$ELSE}
    fTintColor: TalphaColor;
    fAutoCapitalizationType: TALAutoCapitalizationType;
    fTextPromptColor: TalphaColor;
    fEditControl: TEdit;
    {$ENDIF}
    function GetTextPrompt: String;
    procedure setTextPrompt(const Value: String);
    function GetTextPromptColor: TAlphaColor;
    procedure setTextPromptColor(const Value: TAlphaColor);
    function GetTintColor: TAlphaColor;
    procedure setTintColor(const Value: TAlphaColor);
    function GetTextSettings: TTextSettings;
    procedure SetTextSettings(const Value: TTextSettings);
    procedure OnFontChanged(Sender: TObject);
    function getText: String;
    procedure SetText(const Value: String);
    procedure OnChangeTrackingImpl(Sender: TObject);
    {$IF defined(ios) OR defined(android)}
    procedure OnReturnKeyImpl(Sender: TObject);
    {$ENDIF}
    procedure SetOnReturnKey(const Value: TNotifyEvent);
    {$IF (not defined(ios)) and (not defined(android))}
    procedure OnKeyDownImpl(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    {$ENDIF}
    procedure OnEnterImpl(Sender: TObject);
    procedure OnExitImpl(Sender: TObject);
    procedure SetKeyboardType(Value: TVirtualKeyboardType);
    function GetKeyboardType: TVirtualKeyboardType;
    procedure setAutoCapitalizationType(const Value: TALAutoCapitalizationType);
    function GetAutoCapitalizationType: TALAutoCapitalizationType;
    procedure SetPassword(const Value: Boolean);
    function GetPassword: Boolean;
    procedure SetCheckSpelling(const Value: Boolean);
    function GetCheckSpelling: Boolean;
    procedure SetReturnKeyType(const Value: TReturnKeyType);
    function GetReturnKeyType: TReturnKeyType;
    procedure SetDefStyleAttr(const Value: String);
    procedure CreateEditControl;
    function GetContainFocus: Boolean;
    procedure SetMaxLength(const Value: integer);
    function GetMaxLength: integer;
  protected
    function GetDefaultSize: TSizeF; override;
    procedure Loaded; override;
    procedure StrokeChanged(Sender: TObject); override;
    procedure SetSides(const Value: TSides); override;
    function GetCanFocus: Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    {$IF defined(android)}
    property AndroidEditText: JALEditText read GetAndroidEditText;
    {$ELSEIF defined(IOS)}
    property IosTextField: TALIosTextField read GetIosTextField;
    {$ENDIF}
    Procedure AddNativeView;
    Procedure RemoveNativeView;
    Procedure setSelection(const aStart: integer; const aStop: Integer); overload;
    Procedure setSelection(const aindex: integer); overload;
    property ContainFocus: Boolean read GetContainFocus;
  published
    property DefStyleAttr: String read fDefStyleAttr write SetDefStyleAttr; // << android only - the name of An attribute in the current theme that contains a
                                                                            // << reference to a style resource that supplies defaults values for the StyledAttributes.
                                                                            // << exemple of use: https://stackoverflow.com/questions/5051753/how-do-i-apply-a-style-programmatically
                                                                            // << NOTE: !!IMPORTANT!! This properties must be defined the very first because the stream system
                                                                            // <<       must load it the very first
    property TabOrder;
    property TabStop;
    property Cursor default crIBeam;
    property CanFocus default True;
    //property CanParentFocus;
    property DisableFocusEffect;
    property KeyboardType: TVirtualKeyboardType read GetKeyboardType write SetKeyboardType default TVirtualKeyboardType.Default;
    property AutoCapitalizationType: TALAutoCapitalizationType read GetAutoCapitalizationType write SetAutoCapitalizationType default TALAutoCapitalizationType.acNone;
    property ReturnKeyType: TReturnKeyType read GetReturnKeyType write SetReturnKeyType default TReturnKeyType.Default;
    property Password: Boolean read GetPassword write SetPassword default False;
    //property ReadOnly;
    property MaxLength: integer read GetMaxLength write SetMaxLength default 0;
    //property FilterChar;
    property Text: String read getText write SetText;
    property TextSettings: TTextSettings read GetTextSettings write SetTextSettings;
    property Hint;
    property TextPrompt: String read GetTextPrompt write setTextPrompt;
    property TextPromptColor: TAlphaColor read GetTextPromptColor write setTextPromptColor default TalphaColorRec.null; // << null mean use the default TextPromptColor
    property TintColor: TAlphaColor read GetTintColor write setTintColor default TalphaColorRec.null; // << IOS only - the color of the cursor caret and the text selection handles. null mean use the default TintColor
    property AutoTranslate: Boolean read FAutoTranslate write FAutoTranslate default true; // << just the TextPrompt
    property AutoConvertFontFamily: Boolean read FAutoConvertFontFamily write fAutoConvertFontFamily default true;
    property TouchTargetExpansion;
    //property Caret;
    //property KillFocusByReturn; => always true
    property CheckSpelling: Boolean read GetCheckSpelling write SetCheckSpelling default true;
    property ParentShowHint;
    property ShowHint;
    //property OnChange;
    property OnChangeTracking: TNotifyEvent read fOnChangeTracking write fOnChangeTracking;
    property OnReturnKey: TNotifyEvent read fOnReturnKey write SetOnReturnKey;
    //property OnTyping;
    //property OnValidating;
    //property OnValidate;
    //property OnKeyDown; // << not work under android - it's like this with their @{[^# virtual keyboard :(
    //property OnKeyUp; // << not work under android - it's like this with their @{[^# virtual keyboard :(
    property OnEnter: TnotifyEvent Read fOnEnter Write fOnEnter;
    property OnExit: TnotifyEvent Read fOnExit Write fOnExit;
  end;

procedure Register;

implementation

uses {$IF defined(android)}
     System.SysUtils,
     Androidapi.Helpers,
     Androidapi.Input,
     Androidapi.KeyCodes,
     Androidapi.JNI.App,
     Androidapi.JNI.Util,
     FMX.Platform,
     FMX.Platform.Android,
     FMX.Helpers.Android,
     FMX.Forms,
     {$ELSEIF defined(IOS)}
     System.SysUtils,
     Macapi.CoreFoundation,
     iOSapi.CoreGraphics,
     iOSapi.CocoaTypes,
     Macapi.Helpers,
     iOSapi.CoreText,
     FMX.Helpers.iOS,
     FMX.Consts,
     {$endif}
     ALCommon,
     ALString,
     AlFmxCommon;

{**}
type
  TALEditTextSettings = class(TTextSettings)
  public
    constructor Create(const AOwner: TPersistent); override;
  published
    property Font;
    property FontColor;
    property HorzAlign default TTextAlign.Leading;
    property VertAlign default TTextAlign.Center;
  end;

{****************************************************************}
constructor TALEditTextSettings.Create(const AOwner: TPersistent);
begin
  inherited;
  HorzAlign := TTextAlign.Leading;
  VertAlign := TTextAlign.Center;
end;

{$REGION ' ANDROID'}
{$IF defined(android)}

{*********************************************************************************************************************************}
constructor TALAndroidEdit.Create(const AOwner: TComponent; Const aIsMultiline: Boolean = False; const aDefStyleAttr: String = '');
var aLayoutParams: JViewGroup_LayoutParams;
    aScreenSrv: IFMXScreenService;
begin
  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.Create', 'start', TalLogType.VERBOSE);
  {$ENDIF}
  inherited create(AOwner);
  //-----
  if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, aScreenSrv) then FScreenScale := aScreenSrv.GetScreenScale
  else FScreenScale := 1;
  //-----
  FPadding := TBounds.Create(TRectF.Empty);
  CanFocus := True;
  fFormActivateMessageID := TMessageManager.DefaultManager.SubscribeToMessage(TFormActivateMessage, FormActivateHandler);
  fFormDeactivateMessageID := TMessageManager.DefaultManager.SubscribeToMessage(TFormDeactivateMessage, FormDeActivateHandler);
  fApplicationEventMessageID := TMessageManager.DefaultManager.SubscribeToMessage(TApplicationEventMessage, ApplicationEventHandler);
  fOnChangeTracking := nil;
  fOnReturnKey := nil;
  FTextSettings := TALEditTextSettings.Create(Self);
  FTextSettings.OnChanged := OnFontChanged;
  fHideSoftInputOnExit := True;
  fIsMultiline := aIsMultiline;
  fMaxLength := 0;
  fTextPrompt := '';
  fReturnKeyType := tReturnKeyType.Default;
  fKeyboardType := TVirtualKeyboardType.default;
  fPassword := false;
  FFocusChangeListener := TALFocusChangeListener.Create(self);
  FTextWatcher := TALTextWatcher.Create(self);
  FEditorActionListener := TALEditorActionListener.Create(self);
  FSoftInputListener := TALSoftInputListener.Create(self);
  FKeyPreImeListener := TALKeyPreImeListener.Create(self);
  //-----
  inc(ALViewStackCount);
  //-----
  {$IF CompilerVersion <= 31} // berlin
  CallInUIThreadAndWaitFinishing(
    procedure
    begin
  {$ENDIF}

      FLayout := TJALControlHostLayout.JavaClass.init(TAndroidHelper.Activity);
      fLayout.setfocusable(true);               // << this is important to remove the focus from the FeditText
      fLayout.setfocusableInTouchMode(true);    //    else fedittext will always receive back the focus after we remove it
      //-----
      {$IF CompilerVersion > 32} // tokyo
        {$MESSAGE WARN 'Check if viewStack.java in classes.dex is still the same and adjust the IFDEF'}
      {$ENDIF}
      MainActivity.getViewStack.addview(fLayout); // << this will add the view
                                                  //
                                                  //    public class ViewStack {
                                                  //      public void addView(ViewGroup view) {
                                                  //        if (view == null || this.mViews.contains(view)) {
                                                  //          ....
                                                  //        }
                                                  //        this.mWindowManager.addView(view, getLayoutParams(view));
                                                  //        this.mViews.add(view);
                                                  //      }
                                                  //    }
                                                  //
      FNativeViewAttached := True;
      if not fLayout.disableMoveAnimations then begin
        {$IF defined(DEBUG)}
        ALLog('JALControlHostLayout.disableMoveAnimations', 'failed', TalLogType.warn);
        {$ENDIF}
      end;
      //-----
      if aDefStyleAttr = '' then FEditText := TJALEditText.JavaClass.init(TAndroidHelper.Activity)
      else FEditText := TJALEditText.JavaClass.init(TAndroidHelper.Activity, // context: JContext;
                                                    nil, // attrs: JAttributeSet;
                                                    TAndroidHelper. // defStyleAttr: Integer
                                                      Context.
                                                        getResources().
                                                          getIdentifier(StringToJstring(aDefStyleAttr), // name	String: The name of the desired resource.
                                                                        StringToJstring('attr'), // String: Optional default resource type to find, if "type/" is not included in the name. Can be null to require an explicit type.
                                                                        TAndroidHelper.Context.getPackageName())); // String: Optional default package to find, if "package:" is not included in the name. Can be null to require an explicit package.
      fLayout.addview(fEditText);
      //-----
      fEditText.setOnFocusChangeListener(fFocusChangeListener);
      fEditText.addTextChangedListener(fTextWatcher);
      fEditText.setOnEditorActionListener(fEditorActionListener);
      fEditText.SetSoftInputListener(fSoftInputListener);
      fEditText.SetKeyPreImeListener(fKeyPreImeListener);
      //-----
      aLayoutParams := fEditText.getLayoutParams;
      aLayoutParams.width := TJViewGroup_LayoutParams.JavaClass.MATCH_PARENT;
      aLayoutParams.height := TJViewGroup_LayoutParams.JavaClass.MATCH_PARENT;
      fEditText.setLayoutParams(aLayoutParams);
      //-----
      fEditText.setShowSoftInputOnFocus(false);
      if fIsMultiline then fEditText.setSingleLine(False)
      else fEditText.setSingleLine(True);
      DoSetReturnKeyType(fEditText, fReturnKeyType);
      DoSetInputType(fEditText, fKeyboardType, fPassword, fIsMultiline);
      //-----
      MainActivity.getViewStack.addView(nil); // << this will "disable" all the view but i m not sure is we really need to do this
                                              //    but as emb team don't write any comments it's hard to know what really mean
                                              //    NOT_FOCUSABLE_FLAGS and FOCUSABLE_FLAGS. anyway it's cost nothing to do it to be safe
                                              //
                                              //    public class ViewStack {
                                              //      public void addView(ViewGroup view) {
                                              //        if (view == null || this.mViews.contains(view)) {
                                              //          LayoutParams lp;
                                              //          Iterator i$ = this.mViews.iterator();
                                              //          while (i$.hasNext()) {
                                              //            View v = (View) i$.next();
                                              //            lp = getLayoutParams(v);
                                              //            lp.flags = NOT_FOCUSABLE_FLAGS;
                                              //            this.mWindowManager.updateViewLayout(v, lp);
                                              //          }
                                              //          if (view != null) {
                                              //            lp = getLayoutParams(view);
                                              //            lp.flags = FOCUSABLE_FLAGS;
                                              //            this.mWindowManager.updateViewLayout(view, lp);
                                              //            return;
                                              //          }
                                              //          return;
                                              //        }
                                              //        ...
                                              //      }
                                              //    }
                                              //

  {$IF CompilerVersion <= 31} // berlin
    end);
  {$ENDIF}
  //-----
  RealignContent;
  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.Create', 'end', TalLogType.VERBOSE);
  {$ENDIF}
end;

{********************************}
destructor TALAndroidEdit.Destroy;
{$IF CompilerVersion <= 31} // berlin
var aNativeViewAttached: Boolean;
    aTextWatcher: TALTextWatcher;
{$ENDIF}
begin
  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.Destroy', 'start', TalLogType.VERBOSE);
  {$ENDIF}

  TMessageManager.DefaultManager.Unsubscribe(TFormActivateMessage, fFormActivateMessageID);
  TMessageManager.DefaultManager.Unsubscribe(TFormDeactivateMessage, fFormDeactivateMessageID);
  TMessageManager.DefaultManager.Unsubscribe(TApplicationEventMessage, fApplicationEventMessageID);

  dec(ALViewStackCount);

  {$IF CompilerVersion <= 31} // berlin
  FFocusChangeListener.FEditControl := nil;
  FTextWatcher.FEditControl := nil;
  fEditorActionListener.FEditControl := nil;
  FSoftInputListener.FEditControl := nil;
  FKeyPreImeListener.FEditControl := nil;
  aNativeViewAttached := fNativeViewAttached;
  aTextWatcher := fTextWatcher;
  TUIThreadCaller.Call<JALEditText,JALControlHostLayout>(
    procedure (FEditText: JALEditText; FLayout: JALControlHostLayout)
    var fNativeViewAttached: Boolean;
        fTextWatcher: TALTextWatcher;
    begin
      fNativeViewAttached := aNativeViewAttached;
      fTextWatcher := aTextWatcher;
  {$ENDIF}

      fEditText.setVisibility(TJView.JavaClass.INVISIBLE);
      fEditText.setOnFocusChangeListener(nil);
      fEditText.RemoveTextChangedListener(FTextWatcher);
      fEditText.setOnEditorActionListener(nil);
      fEditText.SetSoftInputListener(nil);
      fEditText.SetKeyPreImeListener(nil);

      fLayout.removeAllViews();
      if FNativeViewAttached then begin
        MainActivity.getViewStack.removeView(fLayout);
        FNativeViewAttached := False;
      end;

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText, FLayout);
  {$ENDIF}

  {$IF CompilerVersion <= 31} // berlin
  //unfortunatly i can't make the previous instruction with wait
  //because when the app close, then the wait will never finish :(
  //but doesn't matter we don't need to free the object below, it's
  //we be done automatiquely
  //alfreeandNil(FFocusChangeListener);
  //alfreeandNil(FTextWatcher);
  //alfreeandNil(fEditorActionListener);
  //alfreeandNil(FSoftInputListener);
  //alfreeandNil(FKeyPreImeListener);
  //FEditText := nil;
  //FLayout := nil;
  {$ELSE} //tokyo+
  alfreeandNil(FFocusChangeListener);
  alfreeandNil(FTextWatcher);
  alfreeandNil(fEditorActionListener);
  alfreeandNil(FSoftInputListener);
  alfreeandNil(FKeyPreImeListener);
  FEditText := nil;
  FLayout := nil;
  {$ENDIF}

  ALFreeAndNil(FTextSettings);
  ALFreeAndNil(FPadding);

  inherited;

  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.Destroy', 'end', TalLogType.VERBOSE);
  {$ENDIF}
end;

{*************************************}
procedure TALAndroidEdit.RecalcOpacity;
begin

  inherited;

  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALEditText, Single>(
    procedure (FEditText: JALEditText; AbsoluteOpacity: Single)
    begin
  {$ENDIF}

      fEditText.setAlpha(AbsoluteOpacity);

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText, AbsoluteOpacity);
  {$ENDIF}

end;

{*************************************}
Procedure TALAndroidEdit.AddNativeView;
begin

  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALControlHostLayout>(
    procedure (FLayout: JALControlHostLayout)
    begin
  {$ENDIF}

      if FNativeViewAttached then exit;
      MainActivity.getViewStack.addview(FLayout);
      MainActivity.getViewStack.addview(nil);
      FNativeViewAttached := True;

  {$IF CompilerVersion <= 31} // berlin
    end, FLayout);
  {$ENDIF}

  realignContent;

end;

{****************************************}
Procedure TALAndroidEdit.RemoveNativeView;
begin

  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALControlHostLayout>(
    procedure (FLayout: JALControlHostLayout)
    begin
  {$ENDIF}

      if not FNativeViewAttached then exit;
      MainActivity.getViewStack.Removeview(FLayout);
      FNativeViewAttached := false;

  {$IF CompilerVersion <= 31} // berlin
    end, FLayout);
  {$ENDIF}

end;

{*********************************************************************}
procedure TALAndroidEdit.realignContent(const aForce: boolean = False);

  {~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
  function _GetRealBounds: TRect;
  var aNativeWin: JWindow;
      aContentRect: JRect;
  begin
    aNativeWin := TAndroidHelper.Activity.getWindow;
    if aNativeWin <> nil then begin
      aContentRect := TJRect.Create;
      aNativeWin.getDecorView.getDrawingRect(aContentRect);
      result := Rect(aContentRect.left, aContentRect.top, aContentRect.right, aContentRect.bottom);
    end
    else result := TRect.Empty;
  end;

  {~~~~~~~~~~~~~~~~~~~~~}
  procedure _showContent;
  var aPos: TPointF;
      R: TRect;
      {$IF CompilerVersion <= 31} // berlin
      aNativeViewAttached: Boolean;
      {$ENDIF}
  begin

    aPos := LocalToAbsolute(TPointF.Zero) * FScreenScale;
    R := Rect(Round(aPos.X), Round(aPos.Y), Round(Width * FScreenScale), Round(Height * FScreenScale));

    {$IF CompilerVersion <= 31} // berlin
    aNativeViewAttached := fNativeViewAttached;
    TUIThreadCaller.Call<JALControlHostLayout, JALEditText>(
      procedure (FLayout: JALControlHostLayout; FEditText: JALEditText)
      var fNativeViewAttached: Boolean;
      begin
        fNativeViewAttached := aNativeViewAttached;
    {$ENDIF}

        if not FNativeViewAttached then exit;
        MainActivity.getViewStack.setPosition(fLayout, R.Left, R.Top);
        MainActivity.getViewStack.setSize(fLayout, R.Right, R.Bottom);
        if fEditText.getVisibility <> TJView.JavaClass.VISIBLE then
          fEditText.setVisibility(TJView.JavaClass.VISIBLE);

    {$IF CompilerVersion <= 31} // berlin
      end, FLayout, FEditText);
    {$ENDIF}

  end;

  {~~~~~~~~~~~~~~~~~~~~~}
  procedure _HideContent;
  var R: TRect;
      {$IF CompilerVersion <= 31} // berlin
      aNativeViewAttached: Boolean;
      {$ENDIF}
  begin

    R := _GetRealBounds;

    {$IF CompilerVersion <= 31} // berlin
    aNativeViewAttached := fNativeViewAttached;
    TUIThreadCaller.Call<JALControlHostLayout, JALEditText>(
      procedure (FLayout: JALControlHostLayout; FEditText: JALEditText)
      var fNativeViewAttached: Boolean;
      begin
        fNativeViewAttached := aNativeViewAttached;
    {$ENDIF}

        if not FNativeViewAttached then exit;
        if fEditText.getVisibility <> TJView.JavaClass.INVISIBLE then begin
          fEditText.setVisibility(TJView.JavaClass.INVISIBLE);
          MainActivity.getViewStack.setPosition(fLayout, R.Right * 2 , R.Height * 2);
        end;

    {$IF CompilerVersion <= 31} // berlin
      end, FLayout, FEditText);
    {$ENDIF}

  end;

begin
  {$IF defined(DEBUG)}
  //ALLog('TALAndroidEdit.realignContent', 'realignContent', TalLogType.VERBOSE);
  {$ENDIF}
  if (not aForce) and isUpdating then exit;
  if csdestroying in componentState then exit;
  if (not (csDesigning in ComponentState)) and
     (Root <> nil) and
     (Root.GetObject is TCommonCustomForm) then begin
    if Visible and
       ParentedVisible and
      (TCommonCustomForm(Root.GetObject)).Visible and
      (TCommonCustomForm(Root.GetObject)).Active then _showContent
    else _HideContent;
  end
  else _HideContent;
end;

{***********************************}
procedure TALAndroidEdit.DoEndUpdate;
begin
  inherited;
  realignContent;
end;

{**********************************************************************}
procedure TALAndroidEdit.AncestorVisibleChanged(const Visible: Boolean);
begin
  inherited;
  RealignContent;
end;

{*****************************************}
procedure TALAndroidEdit.DoAbsoluteChanged;
begin
  inherited;
  RealignContent;
end;

{***********************************}
procedure TALAndroidEdit.ChangeOrder;
begin
  inherited;
  RealignContent;
end;

{**************************************}
procedure TALAndroidEdit.VisibleChanged;
begin
  inherited;
  RealignContent;
end;

{*********************************************}
procedure TALAndroidEdit.AncestorParentChanged;
begin
  inherited;
  // stupidly when we do setparent the
  // FisUpdating will be set to the value of the parent BUT without any
  // notifications nor any call to endupdate :(
  RealignContent(true{force});
end;

{*************************************}
procedure TALAndroidEdit.ParentChanged; // << i don't know if i really need it, normally AncestorParentChanged must be enalf but cost nothing to add it
begin
  inherited;
  // stupidly when we do setparent the
  // FisUpdating will be set to the value of the parent BUT without any
  // notifications nor any call to endupdate :(
  RealignContent(true{force});
end;

{******************************}
procedure TALAndroidEdit.Resize;
begin
  inherited;
  RealignContent;
end;

{*******************************}
procedure TALAndroidEdit.DoEnter;
{$IF CompilerVersion <= 31} // berlin
var aALViewStackCount: integer;
{$ENDIF}
begin
  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.DoEnter', 'start' +
                                  ' - ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.VERBOSE);
  {$ENDIF}

  inherited;

  {$IF CompilerVersion <= 31} // berlin
  aALViewStackCount := ALViewStackCount; // << because ALViewStackCount can be accessed only from main Thread
  CallInUIThreadAndWaitFinishing(
    procedure
    var ALViewStackCount: integer;
    begin
      ALViewStackCount := aALViewStackCount;
  {$ENDIF}

      if not FNativeViewAttached then exit;
      if ALViewStackCount > 1 then begin
        MainActivity.getViewStack.Removeview(FLayout);
        MainActivity.getViewStack.addview(FLayout);
        MainActivity.getViewStack.addview(nil);
      end;
      MainActivity.getViewStack.addview(FLayout); // << this will "activate" the view - important to enable the virtual keyboard
                                                  //
                                                  //    public class ViewStack {
                                                  //      public void addView(ViewGroup view) {
                                                  //        if (view == null || this.mViews.contains(view)) {
                                                  //          LayoutParams lp;
                                                  //          Iterator i$ = this.mViews.iterator();
                                                  //          while (i$.hasNext()) {
                                                  //            View v = (View) i$.next();
                                                  //            lp = getLayoutParams(v);
                                                  //            lp.flags = NOT_FOCUSABLE_FLAGS;
                                                  //            this.mWindowManager.updateViewLayout(v, lp);
                                                  //          }
                                                  //          if (view != null) {
                                                  //            lp = getLayoutParams(view);
                                                  //            lp.flags = FOCUSABLE_FLAGS;
                                                  //            this.mWindowManager.updateViewLayout(view, lp);
                                                  //            return;
                                                  //          }
                                                  //          return;
                                                  //        }
                                                  //        ...
                                                  //      }
                                                  //    }
                                                  //

  {$IF CompilerVersion <= 31} // berlin
    end);
  {$ENDIF}


  {$IF CompilerVersion <= 31} // berlin

  sleep(250); // << it's look like we need to wait before the view is fully activated - else the soft keyboard will not work
              // << don't ask me why ! if someone know i would really like to know :)

  CallInUIThreadAndWaitFinishing(
    procedure
    begin
      if not FNativeViewAttached then exit;
      if FEditText.requestFocus then
        FEditText.showSoftInput;
    end);

  {$ELSE} // tokyo+

  TThread.createAnonymousThread(
    Procedure
    Begin

      sleep(250); // << it's look like we need to wait before the view is fully activated - else the soft keyboard will not work
                  // << don't ask me why ! if someone know i would really like to know :)

      TThread.Synchronize(nil,
        procedure
        begin
          if not FNativeViewAttached then exit;
          if IsFocused and FEditText.requestFocus then
            FEditText.showSoftInput;
        end);

      end).start;

  {$ENDIF}

  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.DoEnter', 'end', TalLogType.VERBOSE);
  {$ENDIF}
end;

{******************************}
procedure TALAndroidEdit.DoExit;
{$IF CompilerVersion <= 31} // berlin
var aNativeViewAttached: Boolean;
{$ENDIF}
begin
  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.DoExit', 'start' +
                                 ' - ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.VERBOSE);
  {$ENDIF}

  inherited;

  {$IF CompilerVersion <= 31} // berlin
  aNativeViewAttached := fNativeViewAttached;
  TUIThreadCaller.Call<JALEditText, boolean>( // << when i do CallInUIThreadAndWaitFinishing i have in some situation threadlock :(
    procedure (FEditText: JALEditText; fHideSoftInputOnExit: boolean)
    var fNativeViewAttached: Boolean;
    begin
      fNativeViewAttached := aNativeViewAttached;
  {$ENDIF}

      if not FNativeViewAttached then exit;
      if fHideSoftInputOnExit then fEditText.HideSoftInput;
      fEditText.clearfocus; // << this will gave the focus to the fLayout in fact and in this way remove it from the FeditText
      MainActivity.getViewStack.addView(nil); // << this will "disable" all the view - important to fully close the virtual keyboard
                                              //
                                              //    public class ViewStack {
                                              //      public void addView(ViewGroup view) {
                                              //        if (view == null || this.mViews.contains(view)) {
                                              //          LayoutParams lp;
                                              //          Iterator i$ = this.mViews.iterator();
                                              //          while (i$.hasNext()) {
                                              //            View v = (View) i$.next();
                                              //            lp = getLayoutParams(v);
                                              //            lp.flags = NOT_FOCUSABLE_FLAGS;
                                              //            this.mWindowManager.updateViewLayout(v, lp);
                                              //          }
                                              //          if (view != null) {
                                              //            lp = getLayoutParams(view);
                                              //            lp.flags = FOCUSABLE_FLAGS;
                                              //            this.mWindowManager.updateViewLayout(view, lp);
                                              //            return;
                                              //          }
                                              //          return;
                                              //        }
                                              //        ...
                                              //      }
                                              //    }
                                              //

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText, fHideSoftInputOnExit);
  {$ENDIF}

  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.DoExit', 'end', TalLogType.VERBOSE);
  {$ENDIF}
end;

{************************************}
procedure TALAndroidEdit.RequestFocus;
begin
  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALEditText, Boolean>(
    procedure (FEditText: JALEditText; FNativeViewAttached: Boolean)
    begin
  {$ENDIF}

      if not FNativeViewAttached then exit;
      fEditText.requestFocus;

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText, FNativeViewAttached);
  {$ENDIF}
end;

{*********************************************************************************}
Procedure TALAndroidEdit.setSelection(const aStart: integer; const aStop: Integer);
begin
  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALEditText>(
    procedure (FEditText: JALEditText)
    begin
  {$ENDIF}

      fEditText.setSelection(aStart, aStop);

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText);
  {$ENDIF}
end;

{***********************************************************}
Procedure TALAndroidEdit.setSelection(const aindex: integer);
begin
  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALEditText>(
    procedure (FEditText: JALEditText)
    begin
  {$ENDIF}

      fEditText.setSelection(aindex);

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText);
  {$ENDIF}
end;

{********************************************}
function TALAndroidEdit.getLineHeight: Single;
{$IF CompilerVersion <= 31} // berlin
var aLineHeight: single;
{$ENDIF}
begin
  {$IF CompilerVersion <= 31} // berlin
  CallInUIThreadAndWaitFinishing(
    procedure
    var result: Single;
    begin
  {$ENDIF}

      result := FEditText.getLineHeight / FScreenScale;

  {$IF CompilerVersion <= 31} // berlin
      aLineHeight := Result;
    end);
  result := aLineHeight;
  {$ENDIF}
end;

{********************************************}
function TALAndroidEdit.getLineCount: integer;
{$IF CompilerVersion <= 31} // berlin
var aLineCount: integer;
{$ENDIF}
begin
  {$IF CompilerVersion <= 31} // berlin
  CallInUIThreadAndWaitFinishing(
    procedure
    var result: integer;
    begin
  {$ENDIF}

      result := FEditText.getLineCount;

  {$IF CompilerVersion <= 31} // berlin
      aLineCount := Result;
    end);
  result := aLineCount;
  {$ENDIF}
end;

{*******************************************************************}
procedure TALAndroidEdit.DoSetInputType(const aEditText: JALEditText;
                                        const aKeyboardType: TVirtualKeyboardType;
                                        const aPassword: Boolean;
                                        const aIsMultiline: Boolean);
var aInputType: integer;
begin

  // TYPE_CLASS_DATETIME: Class for dates and times.
  // TYPE_CLASS_NUMBER: Class for numeric text.
  // TYPE_CLASS_PHONE: Class for a phone number.
  // TYPE_CLASS_TEXT: Class for normal text.
  // TYPE_DATETIME_VARIATION_DATE: Default variation of TYPE_CLASS_DATETIME: allows entering only a date.
  // TYPE_DATETIME_VARIATION_NORMAL: Default variation of TYPE_CLASS_DATETIME: allows entering both a date and time.
  // TYPE_DATETIME_VARIATION_TIME: Default variation of TYPE_CLASS_DATETIME: allows entering only a time.
  // TYPE_MASK_CLASS: Mask of bits that determine the overall class of text being given.
  // TYPE_MASK_FLAGS: Mask of bits that provide addition bit flags of options.
  // TYPE_MASK_VARIATION: Mask of bits that determine the variation of the base content class.
  // TYPE_NULL: Special content type for when no explicit type has been specified.
  // TYPE_NUMBER_FLAG_DECIMAL: Flag of TYPE_CLASS_NUMBER: the number is decimal, allowing a decimal point to provide fractional values.
  // TYPE_NUMBER_FLAG_SIGNED: Flag of TYPE_CLASS_NUMBER: the number is signed, allowing a positive or negative sign at the start.
  // TYPE_NUMBER_VARIATION_NORMAL: Default variation of TYPE_CLASS_NUMBER: plain normal numeric text.
  // TYPE_NUMBER_VARIATION_PASSWORD: Variation of TYPE_CLASS_NUMBER: entering a numeric password.
  // TYPE_TEXT_FLAG_AUTO_COMPLETE: Flag for TYPE_CLASS_TEXT: the text editor (which means the application) is performing auto-completion of the text being entered based on its own semantics, which it will present to the user as they type.
  // TYPE_TEXT_FLAG_AUTO_CORRECT: Flag for TYPE_CLASS_TEXT: the user is entering free-form text that should have auto-correction applied to it.
  // TYPE_TEXT_FLAG_CAP_CHARACTERS: Flag for TYPE_CLASS_TEXT: capitalize all characters.
  // TYPE_TEXT_FLAG_CAP_SENTENCES: Flag for TYPE_CLASS_TEXT: capitalize the first character of each sentence.
  // TYPE_TEXT_FLAG_CAP_WORDS: Flag for TYPE_CLASS_TEXT: capitalize the first character of every word.
  // TYPE_TEXT_FLAG_IME_MULTI_LINE: Flag for TYPE_CLASS_TEXT: the regular text view associated with this should not be multi-line, but when a fullscreen input method is providing text it should use multiple lines if it can.
  // TYPE_TEXT_FLAG_MULTI_LINE: Flag for TYPE_CLASS_TEXT: multiple lines of text can be entered into the field.
  // TYPE_TEXT_FLAG_NO_SUGGESTIONS: Flag for TYPE_CLASS_TEXT: the input method does not need to display any dictionary-based candidates.
  // TYPE_TEXT_VARIATION_EMAIL_ADDRESS: Variation of TYPE_CLASS_TEXT: entering an e-mail address.
  // TYPE_TEXT_VARIATION_EMAIL_SUBJECT: Variation of TYPE_CLASS_TEXT: entering the subject line of an e-mail.
  // TYPE_TEXT_VARIATION_FILTER: Variation of TYPE_CLASS_TEXT: entering text to filter contents of a list etc.
  // TYPE_TEXT_VARIATION_LONG_MESSAGE: Variation of TYPE_CLASS_TEXT: entering the content of a long, possibly formal message such as the body of an e-mail.
  // TYPE_TEXT_VARIATION_NORMAL: Default variation of TYPE_CLASS_TEXT: plain old normal text.
  // TYPE_TEXT_VARIATION_PASSWORD: Variation of TYPE_CLASS_TEXT: entering a password.
  // TYPE_TEXT_VARIATION_PERSON_NAME: Variation of TYPE_CLASS_TEXT: entering the name of a person.
  // TYPE_TEXT_VARIATION_PHONETIC: Variation of TYPE_CLASS_TEXT: entering text for phonetic pronunciation, such as a phonetic name field in contacts.
  // TYPE_TEXT_VARIATION_POSTAL_ADDRESS: Variation of TYPE_CLASS_TEXT: entering a postal mailing address.
  // TYPE_TEXT_VARIATION_SHORT_MESSAGE: Variation of TYPE_CLASS_TEXT: entering a short, possibly informal message such as an instant message or a text message.
  // TYPE_TEXT_VARIATION_URI: Variation of TYPE_CLASS_TEXT: entering a URI.
  // TYPE_TEXT_VARIATION_VISIBLE_PASSWORD: Variation of TYPE_CLASS_TEXT: entering a password, which should be visible to the user.
  // TYPE_TEXT_VARIATION_WEB_EDIT_TEXT: Variation of TYPE_CLASS_TEXT: entering text inside of a web form.
  // TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS: Variation of TYPE_CLASS_TEXT: entering e-mail address inside of a web form.
  // TYPE_TEXT_VARIATION_WEB_PASSWORD: Variation of TYPE_CLASS_TEXT: entering password inside of a web form.

  case aKeyboardType of
    TVirtualKeyboardType.Alphabet:              aInputType := TJInputType.JavaClass.TYPE_CLASS_TEXT or TJInputType.JavaClass.TYPE_TEXT_FLAG_NO_SUGGESTIONS;
    TVirtualKeyboardType.URL:                   aInputType := TJInputType.JavaClass.TYPE_CLASS_TEXT or TJInputType.JavaClass.TYPE_TEXT_VARIATION_URI;
    TVirtualKeyboardType.NamePhonePad:          aInputType := TJInputType.JavaClass.TYPE_CLASS_TEXT;
    TVirtualKeyboardType.EmailAddress:          aInputType := TJInputType.JavaClass.TYPE_CLASS_TEXT or TJInputType.JavaClass.TYPE_TEXT_VARIATION_EMAIL_ADDRESS;
    TVirtualKeyboardType.NumbersAndPunctuation: aInputType := TJInputType.JavaClass.TYPE_CLASS_NUMBER or TJInputType.JavaClass.TYPE_NUMBER_FLAG_DECIMAL;
    TVirtualKeyboardType.NumberPad:             aInputType := TJInputType.JavaClass.TYPE_CLASS_NUMBER;
    TVirtualKeyboardType.PhonePad:              aInputType := TJInputType.JavaClass.TYPE_CLASS_PHONE;
    else {TVirtualKeyboardType.Default}         aInputType := TJInputType.JavaClass.TYPE_CLASS_TEXT;
  end;

  if aPassword then begin
    case aKeyboardType of
      TVirtualKeyboardType.NumbersAndPunctuation: aInputType := aInputType or TJInputType.JavaClass.TYPE_NUMBER_VARIATION_PASSWORD;
      TVirtualKeyboardType.NumberPad:             aInputType := aInputType or TJInputType.JavaClass.TYPE_NUMBER_VARIATION_PASSWORD;
      TVirtualKeyboardType.PhonePad:;
      TVirtualKeyboardType.Alphabet:              aInputType := aInputType or TJInputType.JavaClass.TYPE_TEXT_VARIATION_PASSWORD;
      TVirtualKeyboardType.URL:                   aInputType := aInputType or TJInputType.JavaClass.TYPE_TEXT_VARIATION_PASSWORD;
      TVirtualKeyboardType.NamePhonePad:          aInputType := aInputType or TJInputType.JavaClass.TYPE_TEXT_VARIATION_PASSWORD;
      TVirtualKeyboardType.EmailAddress:          aInputType := aInputType or TJInputType.JavaClass.TYPE_TEXT_VARIATION_PASSWORD;
      else {TVirtualKeyboardType.Default}         aInputType := aInputType or TJInputType.JavaClass.TYPE_TEXT_VARIATION_PASSWORD;
    end;
  end;

  if aIsMultiline then aInputType := aInputType or TJInputType.JavaClass.TYPE_TEXT_FLAG_MULTI_LINE;

  aEditText.setInputType(aInputType);

end;

{**************************************************************************}
procedure TALAndroidEdit.setKeyboardType(const Value: TVirtualKeyboardType);
{$IF CompilerVersion <= 31} // berlin
var aPassword: Boolean;
    aIsMultiLine: Boolean;
{$ENDIF}
begin
  if (value <> fKeyboardType) then begin

    fKeyboardType := Value;

    {$IF CompilerVersion <= 31} // berlin
    aPassword := fPassword;
    aIsMultiLine := fIsMultiline;
    TUIThreadCaller.Call<JALEditText>(
      procedure (FEditText: JALEditText)
      var fPassword: Boolean;
          fIsMultiLine: Boolean;
      begin
        fPassword := aPassword;
        fIsMultiLine := aIsMultiline;
    {$ENDIF}

        DoSetInputType(fEditText, Value, fPassword, fIsMultiLine);

    {$IF CompilerVersion <= 31} // berlin
      end, FEditText);
    {$ENDIF}

  end;
end;

{************************************************************}
function TALAndroidEdit.GetKeyboardType: TVirtualKeyboardType;
begin
  result := fKeyboardType;
end;

{*********************************************************}
procedure TALAndroidEdit.setPassword(const Value: Boolean);
{$IF CompilerVersion <= 31} // berlin
var aKeyboardType: TVirtualKeyboardType;
    aIsMultiLine: Boolean;
{$ENDIF}
begin
  if (value <> fPassword) then begin

    fPassword := Value;

    {$IF CompilerVersion <= 31} // berlin
    aKeyboardType := fKeyboardType;
    aIsMultiLine := fIsMultiline;
    TUIThreadCaller.Call<JALEditText>(
      procedure (FEditText: JALEditText)
      var fKeyboardType: TVirtualKeyboardType;
          fIsMultiLine: Boolean;
      begin
        fKeyboardType := aKeyboardType;
        fIsMultiLine := aIsMultiline;
    {$ENDIF}

        DoSetInputType(fEditText, fKeyboardType, Value, fIsMultiLine);

    {$IF CompilerVersion <= 31} // berlin
      end, FEditText);
    {$ENDIF}

  end;
end;

{*******************************************}
function TALAndroidEdit.GetPassword: Boolean;
begin
  result := fPassword;
end;

{**************************************************************}
procedure TALAndroidEdit.setCheckSpelling(const Value: Boolean);
begin
  // do nothing as far as i know their is no much such option but on marshmallow it's activated by default
end;

{************************************************}
function TALAndroidEdit.GetCheckSpelling: Boolean;
begin
  result := false;
end;

{**************************************************************************************************************}
procedure TALAndroidEdit.DoSetReturnKeyType(const aEditText: JALEditText; const aReturnKeyType: TReturnKeyType);
var aimeOptions: integer;
begin
  case aReturnKeyType of
    TReturnKeyType.Done:          aimeOptions := TJEditorInfo.JavaClass.IME_ACTION_DONE;
    TReturnKeyType.Go:            aimeOptions := TJEditorInfo.JavaClass.IME_ACTION_NONE; // TJEditorInfo.JavaClass.IME_ACTION_GO; => https://stackoverflow.com/questions/44708338/setimeactionlabel-or-setimeoptions-not-work-i-always-have-caption-done-on-the
    TReturnKeyType.Next:          aimeOptions := TJEditorInfo.JavaClass.IME_ACTION_NONE; // TJEditorInfo.JavaClass.IME_ACTION_NEXT; => https://stackoverflow.com/questions/44708338/setimeactionlabel-or-setimeoptions-not-work-i-always-have-caption-done-on-the
    TReturnKeyType.Search:        aimeOptions := TJEditorInfo.JavaClass.IME_ACTION_NONE; // TJEditorInfo.JavaClass.IME_ACTION_SEARCH; => https://stackoverflow.com/questions/44708338/setimeactionlabel-or-setimeoptions-not-work-i-always-have-caption-done-on-the
    TReturnKeyType.Send:          aimeOptions := TJEditorInfo.JavaClass.IME_ACTION_NONE; // TJEditorInfo.JavaClass.IME_ACTION_SEND; => https://stackoverflow.com/questions/44708338/setimeactionlabel-or-setimeoptions-not-work-i-always-have-caption-done-on-the
    else {TReturnKeyType.Default} aimeOptions := TJEditorInfo.JavaClass.IME_ACTION_NONE;
  end;
  aEditText.setImeOptions(aimeOptions);
end;

{*********************************************************************}
procedure TALAndroidEdit.setReturnKeyType(const Value: TReturnKeyType);
begin
  if (value <> fReturnKeyType) then begin

    fReturnKeyType := Value;

    {$IF CompilerVersion <= 31} // berlin
    TUIThreadCaller.Call<JALEditText>(
      procedure (FEditText: JALEditText)
      begin
    {$ENDIF}

        DoSetReturnKeyType(fEditText, Value);

    {$IF CompilerVersion <= 31} // berlin
      end, FEditText);
    {$ENDIF}

  end;
end;

{*******************************************************}
function TALAndroidEdit.GetReturnKeyType: TReturnKeyType;
begin
  result := fReturnKeyType;
end;

{*******************************************************}
function TALAndroidEdit.GetLineSpacingMultiplier: single;
{$IF CompilerVersion <= 31} // berlin
var aLineSpacingMultiplier: single;
{$ENDIF}
begin
  {$IF CompilerVersion <= 31} // berlin
  CallInUIThreadAndWaitFinishing(
    procedure
    var result: single;
    begin
  {$ENDIF}

      result := FEditText.getLineSpacingMultiplier;

  {$IF CompilerVersion <= 31} // berlin
      aLineSpacingMultiplier := Result;
    end);
  result := aLineSpacingMultiplier;
  {$ENDIF}
end;

{*********************************************************************}
procedure TALAndroidEdit.SetLineSpacingMultiplier(const Value: single);
begin
  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALEditText>(
    procedure (FEditText: JALEditText)
    begin
  {$ENDIF}

      fEditText.setLineSpacing(fEditText.getLineSpacingExtra, Value);

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText);
  {$ENDIF}
end;

{**************************************************}
function TALAndroidEdit.GetLineSpacingExtra: single;
{$IF CompilerVersion <= 31} // berlin
var aLineSpacingExtra: single;
{$ENDIF}
begin
  {$IF CompilerVersion <= 31} // berlin
  CallInUIThreadAndWaitFinishing(
    procedure
    var result: single;
    begin
  {$ENDIF}

      result := FEditText.getLineSpacingExtra;

  {$IF CompilerVersion <= 31} // berlin
      aLineSpacingExtra := result;
    end);
  result := aLineSpacingExtra;
  {$ENDIF}
end;

{****************************************************************}
procedure TALAndroidEdit.SetLineSpacingExtra(const Value: single);
begin
  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALEditText>(
    procedure (FEditText: JALEditText)
    begin
  {$ENDIF}

      fEditText.setLineSpacing(Value, fEditText.getLineSpacingMultiplier);

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText);
  {$ENDIF}
end;

{********************************************************}
procedure TALAndroidEdit.SetPadding(const Value: TBounds);
begin

  FPadding.Assign(Value);

  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALEditText, Single>(
    procedure (FEditText: JALEditText; fScreenScale: Single)
    begin
  {$ENDIF}

      fEditText.setPadding(round(Value.Left * fScreenScale), round(Value.Top * fScreenScale), round(Value.Right * fScreenScale), round(Value.Bottom * fScreenScale));

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText, FScreenScale);
  {$ENDIF}

end;

{******************************************}
function TALAndroidEdit.GetPadding: TBounds;
begin
  result := FPadding;
end;

{**********************************************************}
procedure TALAndroidEdit.SetMaxLength(const Value: integer);
begin
  if value <> FMaxLength then begin

    {$IF CompilerVersion <= 31} // berlin
    TUIThreadCaller.Call<JALEditText>(
      procedure (FEditText: JALEditText)
      begin
    {$ENDIF}

        fEditText.setMaxLength(Value);

    {$IF CompilerVersion <= 31} // berlin
      end, FEditText);
    {$ENDIF}

  end;
end;

{********************************************}
function TALAndroidEdit.GetMaxLength: integer;
begin
  result := FMaxLength;
end;

{********************************************}
function TALAndroidEdit.GetTextPrompt: String;
begin
  result := fTextPrompt;
end;

{**********************************************************}
procedure TALAndroidEdit.setTextPrompt(const Value: String);
begin
  if Value <> fTextPrompt then begin

    fTextPrompt := Value;

    {$IF CompilerVersion <= 31} // berlin
    TUIThreadCaller.Call<JALEditText>(
      procedure (FEditText: JALEditText)
      begin
    {$ENDIF}

        fEditText.setHint(StrToJCharSequence(Value));

    {$IF CompilerVersion <= 31} // berlin
      end, FEditText);
    {$ENDIF}

  end;
end;

{******************************************************}
function TALAndroidEdit.GetTextPromptColor: TAlphaColor;
{$IF CompilerVersion <= 31} // berlin
var aColor: TAlphaColor;
{$ENDIF}
begin
  {$IF CompilerVersion <= 31} // berlin
  CallInUIThreadAndWaitFinishing(
    procedure
    var result: TAlphaColor;
    begin
  {$ENDIF}

      result := FEditText.getCurrentHintTextColor;

  {$IF CompilerVersion <= 31} // berlin
      aColor := result;
    end);
  result := aColor;
  {$ENDIF}
end;

{********************************************************************}
procedure TALAndroidEdit.setTextPromptColor(const Value: TAlphaColor);
begin

  if Value = TalphaColorRec.null then exit;

  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALEditText>(
    procedure (FEditText: JALEditText)
    begin
  {$ENDIF}

      fEditText.setHintTextColor(Value);

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText);
  {$ENDIF}

end;

{**************************************}
function TALAndroidEdit.getText: String;
{$IF CompilerVersion <= 31} // berlin
var aText: string;
{$ENDIF}
begin
  {$IF CompilerVersion <= 31} // berlin
  // i don't understand why but on some device, just after the app is created
  // and not already fully working then the instruction CallInUIThreadAndWaitFinishing
  // below will never finished :( i see it on a galaxy tab 3 (so low quality device)
  // when in onAfterTextChanged we try to retrieve the text. Anyway i hope in tokyo update 1
  // they will correct the threading problem and this error will dispear ... because
  // else i have no solution
  CallInUIThreadAndWaitFinishing(
    procedure
    var result: String;
    begin
  {$ENDIF}

      result := JCharSequenceToStr(FEditText.gettext);

  {$IF CompilerVersion <= 31} // berlin
      aText := result;
    end);
  result := aText;
  {$ENDIF}
end;

{****************************************************}
procedure TALAndroidEdit.SetText(const Value: String);
begin
  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALEditText>(
    procedure (FEditText: JALEditText)
    begin
  {$ENDIF}

      fEditText.setText(StrToJCharSequence(Value), TJTextView_BufferType.javaClass.EDITABLE);

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText);
  {$ENDIF}
end;

{******************************************************}
procedure TALAndroidEdit.OnFontChanged(Sender: TObject);
var aTypeface: JTypeface;
    aGravity: integer;
    aFontColor: integer;
    aFontSize: single;
    aFontStyle: integer;
    aFontFamily: String;
begin

  aFontColor := integer(ftextsettings.fontcolor);
  aFontSize := ftextsettings.font.size;
  if (TFontStyle.fsBold in ftextsettings.font.style) and
     (TFontStyle.fsItalic in ftextsettings.font.style) then aFontStyle := TJTypeface.JavaClass.BOLD_ITALIC
  else if (TFontStyle.fsBold in ftextsettings.font.style) then aFontStyle := TJTypeface.JavaClass.BOLD
  else if (TFontStyle.fsItalic in ftextsettings.font.style) then aFontStyle := TJTypeface.JavaClass.ITALIC
  else aFontStyle := TJTypeface.JavaClass.NORMAL;
  aFontFamily := ftextsettings.font.Family;
  //-----
  //top	              0x30	     	Push object to the top of its container, not changing its size.
  //bottom	          0x50	     	Push object to the bottom of its container, not changing its size.
  //left	            0x03	     	Push object to the left of its container, not changing its size.
  //right            	0x05      	Push object to the right of its container, not changing its size.
  //center_vertical	  0x10      	Place object in the vertical center of its container, not changing its size.
  //fill_vertical	    0x70      	Grow the vertical size of the object if needed so it completely fills its container.
  //center_horizontal	0x01	     	Place object in the horizontal center of its container, not changing its size.
  //fill_horizontal	  0x07      	Grow the horizontal size of the object if needed so it completely fills its container.
  //center	          0x11	     	Place the object in the center of its container in both the vertical and horizontal axis, not changing its size.
  //fill	            0x77	     	Grow the horizontal and vertical size of the object if needed so it completely fills its container.
  //clip_vertical	    0x80	     	Additional option that can be set to have the top and/or bottom edges of the child clipped to its container's bounds. The clip will be based on the vertical gravity: a top gravity will clip the bottom edge, a bottom gravity will clip the top edge, and neither will clip both edges.
  //clip_horizontal	  0x08       	Additional option that can be set to have the left and/or right edges of the child clipped to its container's bounds. The clip will be based on the horizontal gravity: a left gravity will clip the right edge, a right gravity will clip the left edge, and neither will clip both edges.
  //start	            0x00800003	Push object to the beginning of its container, not changing its size.
  //end	              0x00800005	Push object to the end of its container, not changing its size.
  case ftextsettings.HorzAlign of
    TTextAlign.Center: aGravity := $01; // center_horizontal 0x01
    TTextAlign.Leading: aGravity := $03; // left 0x03
    TTextAlign.Trailing: aGravity := $05; // right 0x05
    else aGravity := $03; // left 0x03
  end;
  case ftextsettings.VertAlign of
    TTextAlign.Center: aGravity := aGravity or $10; // center_vertical 0x10
    TTextAlign.Leading: aGravity := aGravity or $30; // top 0x30
    TTextAlign.Trailing: aGravity := aGravity or $50; // bottom 0x50
    else aGravity := aGravity or $10; // center_vertical 0x10
  end;

  {$IF CompilerVersion <= 31} // berlin
  TUIThreadCaller.Call<JALEditText>(
    procedure (FEditText: JALEditText)
    begin
  {$ENDIF}

      //-----
      fEditText.setTextColor(aFontColor); // << Sets the text color for all the states (normal, selected, focused) to be this color.
      fEditText.setTextSize(TJTypedValue.javaclass.COMPLEX_UNIT_DIP, aFontSize); // << Set the default text size to a given unit and value.
      //-----
      aTypeface := TJTypeface.JavaClass.create(StringToJString(aFontFamily), aFontStyle);
      fEditText.setTypeface(aTypeface); // << Sets the typeface and style in which the text should be displayed. Note that not all
                                        //    Typeface families actually have bold and italic variants, so you may need to use setTypeface(Typeface, int)
                                        //     to get the appearance that you actually want.
      aTypeface := nil;
      fEditText.setgravity(aGravity);

  {$IF CompilerVersion <= 31} // berlin
    end, FEditText);
  {$ENDIF}

end;

{*****************************************************}
function TALAndroidEdit.GetTextSettings: TTextSettings;
begin
  Result := FTextSettings;
end;

{*******************************************************************}
procedure TALAndroidEdit.SetTextSettings(const Value: TTextSettings);
begin
  FTextSettings.Assign(Value);
end;

{***********************************************}
function TALAndroidEdit.GetEditText: JALEditText;
{$IF CompilerVersion <= 31} // berlin
var aEditText: JALEditText;
{$ENDIF}
begin
  {$IF CompilerVersion <= 31} // berlin
  CallInUIThreadAndWaitFinishing(
    procedure
    var result: JALEditText;
    begin
  {$ENDIF}

      result := FEditText;

  {$IF CompilerVersion <= 31} // berlin
      aEditText := result;
    end);
  result := aEditText;
  {$ENDIF}
end;

{*****************************************************************************************}
procedure TALAndroidEdit.ApplicationEventHandler(const Sender: TObject; const M: TMessage);
begin
  {$IF defined(DEBUG)}
  if isfocused and
     (M is TApplicationEventMessage) then begin
     case (M as TApplicationEventMessage).Value.Event of
       TApplicationEvent.FinishedLaunching: ALLog('TALAndroidEdit.ApplicationEventHandler', 'Event: TApplicationEvent.FinishedLaunching', TalLogType.VERBOSE);
       TApplicationEvent.BecameActive: ALLog('TALAndroidEdit.ApplicationEventHandler', 'Event: TApplicationEvent.BecameActive', TalLogType.VERBOSE);
       TApplicationEvent.WillBecomeInactive: ALLog('TALAndroidEdit.ApplicationEventHandler', 'Event: TApplicationEvent.WillBecomeInactive', TalLogType.VERBOSE);
       TApplicationEvent.EnteredBackground: ALLog('TALAndroidEdit.ApplicationEventHandler', 'Event: TApplicationEvent.EnteredBackground', TalLogType.VERBOSE);
       TApplicationEvent.WillBecomeForeground: ALLog('TALAndroidEdit.ApplicationEventHandler', 'Event: TApplicationEvent.WillBecomeForeground', TalLogType.VERBOSE);
       TApplicationEvent.WillTerminate: ALLog('TALAndroidEdit.ApplicationEventHandler', 'Event: TApplicationEvent.WillTerminate', TalLogType.VERBOSE);
       TApplicationEvent.LowMemory: ALLog('TALAndroidEdit.ApplicationEventHandler', 'Event: TApplicationEvent.LowMemory', TalLogType.VERBOSE);
       TApplicationEvent.TimeChange: ALLog('TALAndroidEdit.ApplicationEventHandler', 'Event: TApplicationEvent.TimeChange', TalLogType.VERBOSE);
       TApplicationEvent.OpenURL: ALLog('TALAndroidEdit.ApplicationEventHandler', 'Event: TApplicationEvent.OpenURL', TalLogType.VERBOSE);
     end;
   end;
  {$ENDIF}
  //problem is that as we play with view, the WillBecomeInactive - BecameActive will be call everytime we toggle the
  //view under the MainActivity.getViewStack. so we can't use these event to know that the application resume from
  //background. most easy is to close the virtual keyboard when the application entere in background (EnteredBackground
  //event is call ONLY when application entered in the background so everything is fine
  if isfocused and
     (M is TApplicationEventMessage) and
     ((M as TApplicationEventMessage).Value.Event = TApplicationEvent.EnteredBackground) then resetfocus;
end;

{*************************************************************************************}
procedure TALAndroidEdit.FormActivateHandler(const Sender: TObject; const M: TMessage);
begin
  RealignContent;
end;

{***************************************************************************************}
procedure TALAndroidEdit.FormDeactivateHandler(const Sender: TObject; const M: TMessage);
begin
  RealignContent;
end;

{*******************************************************************************************}
constructor TALAndroidEdit.TALFocusChangeListener.Create(const aEditcontrol: TALAndroidEdit);
begin
  inherited Create;
  FEditcontrol := aEditcontrol;
end;

{*****************************************************************************************}
procedure TALAndroidEdit.TALFocusChangeListener.onFocusChange(v: JView; hasFocus: Boolean);
var aCurrentFocusedControl: TALAndroidEdit;
    aOldHideSoftInputOnExit: Boolean;
begin
  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.onFocusChange', 'hasFocus: ' + alBoolToStrU(hasFocus, 'YES', 'NO') +
                                        ' - ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.VERBOSE);
  {$ENDIF}
  if hasFocus then begin

    {$IF CompilerVersion <= 31} // berlin
    TThread.Queue(nil,
      procedure
      begin
        if fEditControl = nil then exit;
    {$ENDIF}

        {$IF defined(DEBUG)}
        ALLog('TALAndroidEdit.onFocusChange.queue.hasFocus:YES', 'FEditcontrol.isfocused: ' + alBoolToStrU(FEditcontrol.isfocused, 'YES', 'NO'), TalLogType.VERBOSE);
        {$ENDIF}

        if not FEditcontrol.isfocused then begin

          aCurrentFocusedControl := nil;
          aOldHideSoftInputOnExit := False; // to hide stupid warning bug
          if (FEditcontrol.root <> nil) and
             (ALControlNeedKeyboard(FEditcontrol.root.GetFocused)) then begin
            aCurrentFocusedControl := TALAndroidEdit(FEditcontrol.root.GetFocused);
            aOldHideSoftInputOnExit := aCurrentFocusedControl.HideSoftInputOnExit;
            aCurrentFocusedControl.HideSoftInputOnExit := False;
          end;
          try

            FEditcontrol.SetFocus;

          finally
            if aCurrentFocusedControl <> nil then
              aCurrentFocusedControl.HideSoftInputOnExit := aOldHideSoftInputOnExit;
          end;

        end;

    {$IF CompilerVersion <= 31} // berlin
      end);
    {$ENDIF}

  end
  else begin

    {$IF CompilerVersion <= 31} // berlin
    TThread.Queue(nil,
      procedure
      begin
        if fEditControl = nil then exit;
    {$ENDIF}

        {$IF defined(DEBUG)}
        ALLog('TALAndroidEdit.onFocusChange.queue.hasFocus:NO', 'FEditcontrol.isfocused: ' + alBoolToStrU(FEditcontrol.isfocused, 'YES', 'NO'), TalLogType.VERBOSE);
        {$ENDIF}

        if FEditcontrol.isfocused then
          FEditcontrol.resetfocus;

    {$IF CompilerVersion <= 31} // berlin
      end);
    {$ENDIF}

  end;
end;

{*****************************************************************************************}
constructor TALAndroidEdit.TALSoftInputListener.Create(const aEditcontrol: TALAndroidEdit);
begin
  inherited Create;
  FEditControl := aEditcontrol;
end;

{*************************************************************}
procedure TALAndroidEdit.TALSoftInputListener.onSoftInputShown;
var aBounds: TRect;
begin

  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.onSoftInputShown', 'Shown' +
                                           ' - ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.VERBOSE);
  {$ENDIF}

  {$IF CompilerVersion <= 31} // berlin
  TThread.Queue(nil,
    procedure
    begin
  {$ENDIF}

      ALObtainKeyboardRect(aBounds);
      {$IF defined(DEBUG)}
      ALLog('TALAndroidEdit.onSoftInputShown', 'Keyboard Rect bounds:('+inttostr(aBounds.Left)+','+inttostr(aBounds.top)+','+inttostr(aBounds.right)+','+inttostr(aBounds.bottom)+') - bounds-height:'+inttostr(aBounds.height)+' - bounds-width:'+inttostr(aBounds.width), TalLogType.VERBOSE);
      {$ENDIF}
      TMessageManager.DefaultManager.SendMessage(Self, TVKStateChangeMessage.Create(true, aBounds), True);

  {$IF CompilerVersion <= 31} // berlin
    end);
  {$ENDIF}
end;

{**************************************************************}
procedure TALAndroidEdit.TALSoftInputListener.onSoftInputHidden;
begin

  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.onSoftInputHidden', 'Hidden' +
                                            ' - ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.VERBOSE);
  {$ENDIF}

  {$IF CompilerVersion <= 31} // berlin
  TThread.Queue(nil,
    procedure
    begin
  {$ENDIF}

      TMessageManager.DefaultManager.SendMessage(Self, TVKStateChangeMessage.Create(false, Trect.create(0,0,0,0)), True);

  {$IF CompilerVersion <= 31} // berlin
    end);
  {$ENDIF}

end;

{*****************************************************************************************}
constructor TALAndroidEdit.TALKeyPreImeListener.Create(const aEditcontrol: TALAndroidEdit);
begin
  inherited Create;
  FEditControl := aEditcontrol;
end;

{****************************************************************************************************}
function TALAndroidEdit.TALKeyPreImeListener.onKeyPreIme(keyCode: Integer; event: JKeyEvent): Boolean;
begin
  {$IF defined(DEBUG)}
  if event <> nil then ALLog('TALAndroidEdit.onKeyPreIme', 'keyCode: ' + inttostr(keyCode) +
                                                           ' - event: ' + JstringToString(event.toString) +
                                                           ' - ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.VERBOSE)
  else ALLog('TALAndroidEdit.onKeyPreIme', 'keyCode: ' + inttostr(keyCode) +
                                           ' - ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.VERBOSE);
  {$ENDIF}
  if ((event = nil) or (event.getAction = AKEY_EVENT_ACTION_UP)) and
     (keyCode = AKEYCODE_BACK) then begin

    result := true;

    {$IF CompilerVersion <= 31} // berlin
    TThread.Queue(nil,
      procedure
      begin
        if fEditControl = nil then exit;
    {$ENDIF}

        FEditcontrol.resetfocus;

    {$IF CompilerVersion <= 31} // berlin
      end);
    {$ENDIF}

  end
  else result := false;
end;

{***********************************************************************************}
constructor TALAndroidEdit.TALTextWatcher.Create(const aEditcontrol: TALAndroidEdit);
begin
  inherited Create;
  FEditControl := aEditcontrol;
end;

{*********************************************************************}
procedure TALAndroidEdit.TALTextWatcher.afterTextChanged(s: JEditable);
begin

  {$IF defined(DEBUG)}
  ALLog('TALAndroidEdit.afterTextChanged', '(Text changed)' +
                                           ' - ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.VERBOSE);
  {$ENDIF}

  {$IF CompilerVersion <= 31} // berlin
  TThread.Queue(nil,
    procedure
    begin
      if fEditControl = nil then exit;
  {$ENDIF}

      if assigned(fEditControl.fOnChangeTracking) then
        fEditControl.fOnChangeTracking(fEditControl);

  {$IF CompilerVersion <= 31} // berlin
    end);
  {$ENDIF}

end;

{**************************************************************************************************************************}
procedure TALAndroidEdit.TALTextWatcher.beforeTextChanged(s: JCharSequence; start: Integer; count: Integer; after: Integer);
begin
//nothing to do
end;

{***********************************************************************************************************************}
procedure TALAndroidEdit.TALTextWatcher.onTextChanged(s: JCharSequence; start: Integer; before: Integer; count: Integer);
begin
//nothing to do
end;

{********************************************************************************************}
constructor TALAndroidEdit.TALEditorActionListener.Create(const aEditcontrol: TALAndroidEdit);
begin
  inherited Create;
  FEditControl := aEditcontrol;
  fIsMultiLineEditControl := FEditControl.fIsMultiline;
end;

{*************************************************************************************************************************}
function TALAndroidEdit.TALEditorActionListener.onEditorAction(v: JTextView; actionId: Integer; event: JKeyEvent): Boolean;
begin
  {$IF defined(DEBUG)}
   if event <> nil then ALLog('TALAndroidEdit.onEditorAction', 'actionId: ' + inttostr(actionId) +
                                                               ' - event: ' + JstringToString(event.toString) +
                                                               ' - ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.VERBOSE)
   else ALLog('TALAndroidEdit.onEditorAction', 'actionId: ' + inttostr(actionId) +
                                               ' - ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.VERBOSE);
  {$ENDIF}
  //IME_ACTION_DONE: the action key performs a "done" operation, typically meaning there is nothing more to input and the IME will be closed.
  //IME_ACTION_GO: the action key performs a "go" operation to take the user to the target of the text they typed. Typically used, for example, when entering a URL.
  //IME_ACTION_NEXT: the action key performs a "next" operation, taking the user to the next field that will accept text.
  //IME_ACTION_NONE: there is no available action.
  //IME_ACTION_PREVIOUS: like IME_ACTION_NEXT, but for moving to the previous field. This will normally not be used to specify an action (since it precludes IME_ACTION_NEXT), but can be returned to the app if it sets IME_FLAG_NAVIGATE_PREVIOUS.
  //IME_ACTION_SEARCH: the action key performs a "search" operation, taking the user to the results of searching for the text they have typed (in whatever context is appropriate).
  //IME_ACTION_SEND: the action key performs a "send" operation, delivering the text to its target. This is typically used when composing a message in IM or SMS where sending is immediate.
  //IME_ACTION_UNSPECIFIED: no specific action has been associated with this editor, let the editor come up with its own if it can.
  if (actionId = TJEditorInfo.javaClass.IME_ACTION_UNSPECIFIED) or // IME_ACTION_UNSPECIFIED = the return key
     (actionId = TJEditorInfo.javaClass.IME_ACTION_DONE) or
     (actionId = TJEditorInfo.javaClass.IME_ACTION_GO) or
     (actionId = TJEditorInfo.javaClass.IME_ACTION_NEXT) or
     (actionId = TJEditorInfo.javaClass.IME_ACTION_SEARCH) or
     (actionId = TJEditorInfo.javaClass.IME_ACTION_SEND) then begin

    if fIsMultiLineEditControl and (actionId = TJEditorInfo.javaClass.IME_ACTION_UNSPECIFIED) then begin
      result := False;
      Exit;
    end;

    result := true;

    {$IF CompilerVersion <= 31} // berlin
    TThread.Queue(nil,
      procedure
      begin
        if fEditControl = nil then exit;
    {$ENDIF}

        if assigned(FEditControl.fOnReturnKey) then FEditControl.fOnReturnKey(fEditControl)
        else FEditcontrol.resetfocus;

    {$IF CompilerVersion <= 31} // berlin
      end);
    {$ENDIF}

  end
  else result := false;
end;

{$endif}
{$ENDREGION}

{$REGION ' IOS'}
{$IF defined(ios)}

{*********************************}
constructor TALIosTextField.Create;
begin
  inherited;
  FTextFieldDelegate := TALIosTextFieldDelegate.Create(Self);
  View.setExclusiveTouch(True);
  View.setBorderStyle(UITextBorderStyleNone);
  View.setDelegate((FTextFieldDelegate as ILocalObject).GetObjectID);
  RegisterNativeEventHandler('ControlEventEditingChanged', UIControlEventEditingChanged);
  RegisterNativeEventHandler('ControlEventEditingDidEnd', UIControlEventEditingDidEnd);
end;

{***********************************************************}
constructor TALIosTextField.Create(const AControl: TControl);
begin
  fEditControl := TalIosEdit(AControl);
  inherited;
end;

{*********************************}
destructor TALIosTextField.Destroy;
begin
  UnRegisterNativeEventHandler('ControlEventEditingChanged', UIControlEventEditingChanged);
  UnRegisterNativeEventHandler('ControlEventEditingDidEnd', UIControlEventEditingDidEnd);
  View.setDelegate(nil);
  ALFreeAndNil(FTextFieldDelegate);
  inherited;
end;

{********************************************************}
function TALIosTextField.canBecomeFirstResponder: Boolean;
begin
  Result := Control.CanFocus and Control.HitTest;
end;

{***********************************************************************************}
function TALIosTextField.canPerformAction(action: SEL; withSender: Pointer): Boolean;
begin
  Result := UIView(Super).canPerformAction(action, withSender);
end;

{***************************************************}
procedure TALIosTextField.ControlEventEditingChanged;
begin
  {$IF defined(DEBUG)}
  ALLog('TALIosTextField.ControlEventEditingChanged', '', TalLogType.VERBOSE);
  {$ENDIF}
  if assigned(fEditControl.fOnChangeTracking) then
    fEditControl.fOnChangeTracking(fEditControl);
end;

{**************************************************}
procedure TALIosTextField.ControlEventEditingDidEnd;
begin
  {$IF defined(DEBUG)}
  ALLog('TALIosTextField.ControlEventEditingDidEnd', '', TalLogType.VERBOSE);
  {$ENDIF}
  if assigned(fEditControl.fOnChangeTracking) then
    fEditControl.fOnChangeTracking(fEditControl);  // << when we change the word via the sugestion (clicking on the selection) then ControlEventEditingChanged is not fired
                                                   //    imediatly, only on the next key press ... but if we don't press any key but instead close
                                                   //    the keyboad then the event will be never fired ! so we catch here this case
end;

{*****************************************************}
function TALIosTextField.GetObjectiveCClass: PTypeInfo;
begin
  Result := TypeInfo(IALUITextField);
end;

{********************************************}
function TALIosTextField.GetView: UITextField;
begin
  Result := inherited GetView<UITextField>;
end;

{****************************************************************************}
constructor TALIosTextFieldDelegate.Create(const ATextField: TALIosTextField);
begin
  inherited Create;
  FTextField := ATextField;
  if FTextField = nil then
    raise EArgumentNilException.Create(Format(SWrongParameter, ['ATextField']));
end;

{***********************************************************************************************************************************************}
function TALIosTextFieldDelegate.textField(textField: UITextField; shouldChangeCharactersInRange: NSRange; replacementString: NSString): Boolean;
var aText: NSString;
begin
  if FTextField.FEditControl.maxLength > 0 then begin

    //https://stackoverflow.com/questions/433337/set-the-maximum-character-length-of-a-uitextfield
    aText := TNSString.Wrap(textField.text);
    if shouldChangeCharactersInRange.length + shouldChangeCharactersInRange.location > aText.length then exit(false);
    result := aText.length + replacementString.length - shouldChangeCharactersInRange.length <= NSUInteger(FTextField.FEditControl.maxLength);

  end
  else Result := True;
end;

{*********************************************************************************}
procedure TALIosTextFieldDelegate.textFieldDidBeginEditing(textField: UITextField);
begin
  if not FTextField.Control.IsFocused then
    FTextField.Control.SetFocus;
end;

{*******************************************************************************}
procedure TALIosTextFieldDelegate.textFieldDidEndEditing(textField: UITextField);
begin
end;

{********************************************************************************************}
function TALIosTextFieldDelegate.textFieldShouldBeginEditing(textField: UITextField): Boolean;
begin
  Result := True;
end;

{*************************************************************************************}
function TALIosTextFieldDelegate.textFieldShouldClear(textField: UITextField): Boolean;
begin
  Result := true;
end;

{******************************************************************************************}
function TALIosTextFieldDelegate.textFieldShouldEndEditing(textField: UITextField): Boolean;
begin
  Result := True;
end;

{**************************************************************************************}
function TALIosTextFieldDelegate.textFieldShouldReturn(textField: UITextField): Boolean;
begin
  FTextField.ControlEventEditingDidEnd;
  if assigned(FTextField.fEditControl.fOnReturnKey) then FTextField.fEditControl.fOnReturnKey(FTextField.fEditControl)
  else FTextField.ResetFocus;
  Result := true;
end;

{************************************************}
constructor TalIosEdit.Create(AOwner: TComponent);
begin
  inherited create(AOwner);
  fMaxLength := 0;
  CanFocus := True;
  fOnChangeTracking := nil;
  FOnReturnKey := nil;
  fTextPromptColor := TalphaColorRec.Null;
  FTextSettings := TALEditTextSettings.Create(Self);
  FTextSettings.OnChanged := OnFontChanged;
  FTextField := TalIosTextField.create(self);
  SetReturnKeyType(tReturnKeyType.Default);
  SetKeyboardType(TVirtualKeyboardType.default);
  setAutoCapitalizationType(TALAutoCapitalizationType.acNone);
  SetPassword(false);
  SetCheckSpelling(True);
end;

{****************************}
destructor TalIosEdit.Destroy;
begin
  ALfreeandNil(FTextField);
  ALFreeAndNil(FTextSettings);
  inherited Destroy;
end;

{**********************************************************************}
procedure TalIosEdit.SetKeyboardType(const Value: TVirtualKeyboardType);
var aUIKeyboardType: UIKeyboardType;
begin
  case Value of
    TVirtualKeyboardType.NumbersAndPunctuation: aUIKeyboardType := UIKeyboardTypeNumbersAndPunctuation;
    TVirtualKeyboardType.NumberPad:             aUIKeyboardType := UIKeyboardTypeNumberPad;
    TVirtualKeyboardType.PhonePad:              aUIKeyboardType := UIKeyboardTypePhonePad;
    TVirtualKeyboardType.Alphabet:              aUIKeyboardType := UIKeyboardTypeDefault;
    TVirtualKeyboardType.URL:                   aUIKeyboardType := UIKeyboardTypeURL;
    TVirtualKeyboardType.NamePhonePad:          aUIKeyboardType := UIKeyboardTypeNamePhonePad;
    TVirtualKeyboardType.EmailAddress:          aUIKeyboardType := UIKeyboardTypeEmailAddress;
    else {TVirtualKeyboardType.Default}         aUIKeyboardType := UIKeyboardTypeDefault;
  end;
  FTextField.View.setKeyboardType(aUIKeyboardType);
end;

{********************************************************}
function TalIosEdit.GetKeyboardType: TVirtualKeyboardType;
var aUIKeyboardType: UIKeyboardType;
begin
  aUIKeyboardType := FTextField.View.KeyboardType;
  case aUIKeyboardType of
    UIKeyboardTypeNumbersAndPunctuation: result := TVirtualKeyboardType.NumbersAndPunctuation;
    UIKeyboardTypeNumberPad:             result := TVirtualKeyboardType.NumberPad;
    UIKeyboardTypePhonePad:              result := TVirtualKeyboardType.PhonePad;
    UIKeyboardTypeURL:                   result := TVirtualKeyboardType.URL;
    UIKeyboardTypeNamePhonePad:          result := TVirtualKeyboardType.NamePhonePad;
    UIKeyboardTypeEmailAddress:          result := TVirtualKeyboardType.EmailAddress;
    else                                 result := TVirtualKeyboardType.Default;
  end;
end;

{*************************************************************************************}
procedure TalIosEdit.setAutoCapitalizationType(const Value: TALAutoCapitalizationType);
var aUITextAutoCapitalizationType: UITextAutoCapitalizationType;
begin
  case Value of
    TALAutoCapitalizationType.acWords:          aUITextAutoCapitalizationType := UITextAutoCapitalizationTypeWords;
    TALAutoCapitalizationType.acSentences:      aUITextAutoCapitalizationType := UITextAutoCapitalizationTypeSentences;
    TALAutoCapitalizationType.acAllCharacters:  aUITextAutoCapitalizationType := UITextAutoCapitalizationTypeAllCharacters;
    else {TALAutoCapitalizationType.acNone}     aUITextAutoCapitalizationType := UITextAutoCapitalizationTypeNone;
  end;
  FTextField.View.setAutoCapitalizationType(aUITextAutoCapitalizationType);
end;

{***********************************************************************}
function TalIosEdit.GetAutoCapitalizationType: TALAutoCapitalizationType;
var aUITextAutoCapitalizationType: UITextAutoCapitalizationType;
begin
  aUITextAutoCapitalizationType := FTextField.View.AutoCapitalizationType;
  case aUITextAutoCapitalizationType of
    UITextAutoCapitalizationTypeWords:         result := TALAutoCapitalizationType.acWords;
    UITextAutoCapitalizationTypeSentences:     result := TALAutoCapitalizationType.acSentences;
    UITextAutoCapitalizationTypeAllCharacters: result := TALAutoCapitalizationType.acAllCharacters;
    else                                       result := TALAutoCapitalizationType.acNone;
  end;
end;

{*****************************************************}
procedure TalIosEdit.SetPassword(const Value: Boolean);
begin
  FTextField.View.setSecureTextEntry(Value);
end;

{***************************************}
function TalIosEdit.GetPassword: Boolean;
begin
  result := FTextField.View.isSecureTextEntry;
end;

{**********************************************************}
procedure TalIosEdit.SetCheckSpelling(const Value: Boolean);
begin
  if Value then begin
    FTextField.View.setSpellCheckingType(UITextSpellCheckingTypeYes);
    FTextField.View.setAutocorrectionType(UITextAutocorrectionTypeDefault);
  end
  else begin
    FTextField.View.setSpellCheckingType(UITextSpellCheckingTypeNo);
    FTextField.View.setAutocorrectionType(UITextAutocorrectionTypeNo);
  end;
end;

{********************************************}
function TalIosEdit.GetCheckSpelling: Boolean;
begin
  result := FTextField.View.SpellCheckingType = UITextSpellCheckingTypeYes;
end;

{*****************************************************************}
procedure TalIosEdit.setReturnKeyType(const Value: TReturnKeyType);
var aUIReturnKeyType: UIReturnKeyType;
begin
  case Value of
    TReturnKeyType.Done:           aUIReturnKeyType := UIReturnKeyDone;
    TReturnKeyType.Go:             aUIReturnKeyType := UIReturnKeyGo;
    TReturnKeyType.Next:           aUIReturnKeyType := UIReturnKeyNext;
    TReturnKeyType.Search:         aUIReturnKeyType := UIReturnKeySearch;
    TReturnKeyType.Send:           aUIReturnKeyType := UIReturnKeySend;
    else {TReturnKeyType.Default}  aUIReturnKeyType := UIReturnKeyDefault;
  end;
  FTextField.View.setReturnKeyType(aUIReturnKeyType);
end;

{***************************************************}
function TalIosEdit.GetReturnKeyType: TReturnKeyType;
var aUIReturnKeyType: UIReturnKeyType;
begin
  aUIReturnKeyType := FTextField.View.ReturnKeyType;
  case aUIReturnKeyType of
    UIReturnKeyDone:    result := TReturnKeyType.Done;
    UIReturnKeyGo:      result := TReturnKeyType.Go;
    UIReturnKeyNext:    result := TReturnKeyType.Next;
    UIReturnKeySearch:  result := TReturnKeyType.Search;
    UIReturnKeySend:    result := TReturnKeyType.Send;
    else                result := TReturnKeyType.Default;
  end;
end;

{****************************************}
function TalIosEdit.GetTextPrompt: String;
begin
  Result := NSStrToStr(FTextField.View.placeholder);
end;

{******************************************************}
procedure TalIosEdit.setTextPrompt(const Value: String);
begin
  applyTextPromptWithColor(Value, fTextPromptColor);
end;

{**************************************************}
function TalIosEdit.GetTextPromptColor: TAlphaColor;
begin
  result := fTextPromptColor;
end;

{****************************************************************}
procedure TalIosEdit.setTextPromptColor(const Value: TAlphaColor);
begin
  if Value <> fTextPromptColor then begin
    fTextPromptColor := Value;
    applyTextPromptWithColor(GetTextPrompt, fTextPromptColor);
  end;
end;

{*******************************************************************************************}
procedure TalIosEdit.applyTextPromptWithColor(const aStr: String; const aColor: TAlphaColor);
var aTextPromptAttr: NSMutableAttributedString;
    aTextRange: NSRange;
    aUIColor: UIColor;
begin
  if (aColor = tAlphaColorRec.Null) or aStr.IsEmpty then FTextField.View.setPlaceholder(StrToNSStr(aStr))
  else begin

    aTextPromptAttr := TNSMutableAttributedString.Wrap(TNSMutableAttributedString.Alloc.initWithString(StrToNSStr(aStr)));
    try

      aTextPromptAttr.beginEditing;
      try

        aTextRange := NSMakeRange(0, aStr.Length);
        aUIColor := AlphaColorToUIColor(aColor);
        aTextPromptAttr.addAttribute(NSForegroundColorAttributeName, (aUIColor as ILocalObject).GetObjectID, aTextRange);
        //NOTE: if i try to release the aUIColor i have an exception
        //      so it's seam something acquire it

      finally
        aTextPromptAttr.endEditing;
      end;

      FTextField.View.setAttributedPlaceholder(aTextPromptAttr);

    finally
      aTextPromptAttr.release;
    end;

  end;
end;

{********************************************}
function TalIosEdit.GetTintColor: TAlphaColor;
var red: CGFloat;
    green: CGFloat;
    blue: CGFloat;
    alpha: CGFloat;
begin
  if not FTextField.View.tintColor.getRed(@red, @green, @blue, @alpha) then result := TalphaColorRec.Null
  else result := TAlphaColorF.Create(red, green, blue, alpha).ToAlphaColor;
end;

{**********************************************************}
procedure TalIosEdit.setTintColor(const Value: TAlphaColor);
begin
  if Value <> TalphaColorRec.Null then
    FTextField.View.setTintColor(AlphaColorToUIColor(Value));
end;

{**********************************}
function TalIosEdit.getText: String;
begin
  result := NSStrToStr(TNSString.Wrap(FTextField.View.text));
end;

{************************************************}
procedure TalIosEdit.SetText(const Value: String);
begin
  FTextField.View.setText(StrToNSStr(Value));
end;

{*********************************}
procedure TalIosEdit.DoFontChanged;
var aDictionary: NSDictionary;
    aFontRef: CTFontRef;
begin

    //Font
    aFontRef := ALGetCTFontRef(fTextSettings.Font.Family, fTextSettings.Font.Size, fTextSettings.Font.Style);
    if aFontRef <> nil then begin
      try

        aDictionary := TNSDictionary.Wrap(
                         TNSDictionary.OCClass.dictionaryWithObject(
                           aFontRef,
                           (TNSString.Wrap(kCTFontAttributeName) as ILocalObject).GetObjectID));
        FTextField.View.setdefaultTextAttributes(aDictionary); // << Setting this property applies the specified attributes to the entire
                                                               // << text of the text field. Unset attributes maintain their default values.
                                                               // << note: seam that i can't later call aDictionary.release or i have an error

        //i need to put this also in the aDictionary elso but i don't know yet how to put in
        //aDictionary more than one item ... and sincerely i don't need fsUnderline !!
        //var aUnderline: CFNumberRef;
        //    aValue: Cardinal;
        //if TFontStyle.fsUnderline in fTextSettings.Font.Style then begin
        //  aValue := kCTUnderlineStyleSingle;
        //  aUnderline := CFNumberCreate(nil, kCFNumberSInt32Type, @aValue);
        //  try
        //    FAttributedString.addAttribute(TNSString.Wrap(kCTUnderlineStyleAttributeName), aUnderline, aTextRange);
        //  finally
        //    CFRelease(aUnderline);
        //  end;
        //end;

      finally
        CFRelease(aFontRef);
      end;
    end;

    //TextAlignment and TextColor
    FTextField.View.setTextAlignment(TextAlignToUITextAlignment(fTextSettings.HorzAlign));
    FTextField.View.setTextColor(AlphaColorToUIColor(fTextSettings.FontColor));

end;

{**************************************************}
procedure TalIosEdit.OnFontChanged(Sender: TObject);
begin
  DoFontChanged;
end;

{*************************************************}
function TalIosEdit.GetTextSettings: TTextSettings;
begin
  Result := FTextSettings;
end;

{***************************************************************}
procedure TalIosEdit.SetTextSettings(const Value: TTextSettings);
begin
  FTextSettings.Assign(Value);
end;

{*********************************}
procedure TalIosEdit.DoRootChanged;
begin
  inherited;
  FTextField.RootChanged(Root);
end;

{**************************}
procedure TalIosEdit.Resize;
begin
  inherited;
  FTextField.size := Size.size;
end;

{***************************************}
procedure TalIosEdit.ClipChildrenChanged;
begin
  inherited;
  FTextField.SetClipChildren(ClipChildren);
end;

{*************************************}
procedure TalIosEdit.DoAbsoluteChanged;
begin
  inherited;
  if not (csLoading in ComponentState) then
    FTextField.UpdateFrame;
end;

{**********************************}
procedure TalIosEdit.VisibleChanged;
begin
  inherited;
  FTextField.SetVisible(Visible);
end;

{*******************************}
procedure TalIosEdit.ChangeOrder;
begin
  inherited;
  FTextField.ChangeOrder;
end;

{*********************************}
procedure TalIosEdit.RecalcOpacity;
begin
  inherited;
  FTextField.setAlpha(AbsoluteOpacity);
end;

{*********************************}
procedure TalIosEdit.RecalcEnabled;
begin
  inherited;
  FTextField.SetAbsoluteEnabled(AbsoluteEnabled);
end;

{*********************************}
Procedure TalIosEdit.AddNativeView;
begin
  visible := true;
end;

{************************************}
Procedure TalIosEdit.RemoveNativeView;
begin
  visible := False;
end;

{******************************************************************}
procedure TalIosEdit.AncestorVisibleChanged(const Visible: Boolean);
begin
  inherited;
  if FTextField <> nil then FTextField.AncestorVisibleChanged;  // << this proc is called during the ondestroy also when FTextField is already destroyed
end;

{*****************************************}
procedure TalIosEdit.AncestorParentChanged;
begin
  inherited;
  if FTextField <> nil then FTextField.RefreshNativeParent;  // << this proc is called during the ondestroy also when FTextField is already destroyed
end;

{*********************************}
procedure TalIosEdit.ParentChanged;
begin
  inherited;
  if FTextField <> nil then FTextField.RefreshNativeParent; // << this proc is called during the ondestroy also when FTextField is already destroyed
end;

{********************************************************************}
function TalIosEdit.PointInObjectLocal(X: Single; Y: Single): Boolean;
begin
  result := FTextField.PointInObjectLocal(X, Y);
end;

{***************************}
procedure TalIosEdit.DoEnter;
begin
  {$IF defined(DEBUG)}
  ALLog('TalIosEdit.DoEnter', '', TalLogType.VERBOSE);
  {$ENDIF}
  inherited DoEnter;
  FTextField.SetFocus;
end;

{**************************}
procedure TalIosEdit.DoExit;
begin
  {$IF defined(DEBUG)}
  ALLog('TalIosEdit.DoExit', '', TalLogType.VERBOSE);
  {$ENDIF}
  inherited DoExit;
  FTextField.ResetFocus;
end;

{*******************************}
procedure TalIosEdit.DoEndUpdate;
begin
  inherited;
  if FTextField <> nil then FTextField.RefreshNativeParent; // << without this, in some case when we are doing beginupdate to the TEdit
                                                            // << (because in android for exemple we would like to not refresh the position of the control during calculation)
                                                            // << then when we do endupdate the control is not paint or lost somewhere
end;

{$endif}
{$ENDREGION}

{*********************************************}
constructor TALEdit.Create(AOwner: TComponent);
begin
  inherited;
  fDefStyleAttr := '';
  FAutoTranslate := true;
  FAutoConvertFontFamily := True;
  fOnChangeTracking := nil;
  FOnReturnKey := nil;
  fOnEnter := nil;
  fOnExit := nil;
  Cursor := crIBeam;
  CanFocus := True;
  CanParentFocus := False; // else you must rewrite the GetCanFocus
  //-----
  fEditControl := nil;
  {$IF defined(android)}
  //i use this way to know that the compoment
  //will load it's properties from the dfm
  if (aOwner = nil) or
     (not (csloading in aOwner.ComponentState)) then CreateEditControl; // because we must first know the value of DefStyleAttr to create the fEditControl
  {$ELSE}
  CreateEditControl;
  {$ENDIF}
  //-----
  {$IF (not defined(android)) and (not defined(IOS))}
  fTextPromptColor := TalphaColorRec.Null;
  {$ENDIF}
  {$IF (not defined(IOS))}
  fTintColor := TalphaColorRec.Null;
  fAutoCapitalizationType := TALAutoCapitalizationType.acNone;
  {$ENDIF}
  //-----
  FTextSettings := TALEditTextSettings.Create(Self);
  FTextSettings.OnChanged := OnFontChanged;
  //-----
  fill.DefaultColor := $ffffffff;
  fill.Color := $ffffffff;
  stroke.OnChanged := Nil;
  stroke.DefaultKind := TBrushKind.none;
  stroke.kind := TBrushKind.none;
  stroke.OnChanged := StrokeChanged;
end;

{*************************}
destructor TALEdit.Destroy;
begin
  ALFreeAndNil(FTextSettings);
  ALFreeAndNil(fEditControl, false{adelayed}, false{aRefCountWarn}); // << will call disposeOF under ARC so it's ok
  inherited;
end;

{**********************************}
procedure TALEdit.CreateEditControl;
begin
  if fEditControl <> nil then exit;
  {$IF defined(android)}
  fEditControl := TALAndroidEdit.Create(self, false, fDefStyleAttr);
  fEditControl.Parent := self;
  FeditControl.Stored := False;
  FeditControl.SetSubComponent(True);
  FeditControl.Locked := True;
  FeditControl.OnReturnKey := nil; // noops operation
  {$ELSEIF defined(ios)}
  fEditControl := TALIosEdit.Create(self);
  fEditControl.Parent := self;
  FeditControl.Stored := False;
  FeditControl.SetSubComponent(True);
  FeditControl.Locked := True;
  fEditControl.AutoCapitalizationType := TALAutoCapitalizationType.acNone; // noops operation
  FeditControl.OnReturnKey := nil; // noops operation
  {$ELSE}
  fEditControl := TEdit.Create(self);
  fEditControl.Parent := self;
  FeditControl.Stored := False;
  FeditControl.SetSubComponent(True);
  FeditControl.Locked := True;
  fEditControl.ControlType := TcontrolType.Styled; // << on windows platform is not good as Styled
  FeditControl.StyleLookup := 'transparentedit';
  FeditControl.StyledSettings := []; // Family, Size, Style, FontColor, Other
  fEditControl.KillFocusByReturn := True;
  FeditControl.OnKeyDown := OnKeyDownImpl;
  {$ENDIF}
  fEditControl.Align := TAlignLayout.Client;
  FeditControl.OnChangeTracking := OnChangeTrackingImpl;
  FeditControl.OnEnter := OnEnterImpl;
  FeditControl.OnExit := OnExitImpl;
  fEditControl.Password := false; // noops operation
  fEditControl.ReturnKeyType := tReturnKeyType.Default;  // noops operation
  fEditControl.KeyboardType := TVirtualKeyboardType.Default; // noops operation
  fEditControl.CheckSpelling := True;
  fEditControl.MaxLength := 0; // noops operation
end;

{***********************}
procedure TALEdit.Loaded;
begin
  if FEditControl = nil then CreateEditControl;
  //-----
  if (AutoConvertFontFamily) and
     (TextSettings.Font.Family <> '') and
     (not (csDesigning in ComponentState)) then
      TextSettings.Font.Family := ALConvertFontFamily(TextSettings.Font.Family, TextSettings.Font.Style);
  //-----
  inherited;
  //-----
  if (AutoTranslate) and
     (TextPrompt <> '') and
     (not (csDesigning in ComponentState)) then
      TextPrompt := ALTranslate(TextPrompt);
  //-----
  StrokeChanged(stroke);
  OnFontChanged(nil);
end;

{*****************************************************}
procedure TALEdit.SetDefStyleAttr(const Value: String);
begin
  if Value <> fDefStyleAttr then begin
    fDefStyleAttr := Value;
    {$IFDEF ANDROID}
    ALFreeAndNil(fEditControl, false{adelayed}, false{aRefCountWarn}); // << will call disposeOF under ARC so it's ok
    CreateEditControl;
    {$ENDIF}
  end;
end;

{**************************************}
function TALEdit.GetDefaultSize: TSizeF;
begin
  Result := TSizeF.Create(100, 22);
end;

{********************}
{$IF defined(android)}
function TALEdit.GetAndroidEditText: JALEditText;
begin
  if FEditControl = nil then CreateEditControl;
  result := fEditControl.EditText;
end;
{$ENDIF}

{****************}
{$IF defined(IOS)}
function TALEdit.GetIosTextField: TALIosTextField;
begin
  if FEditControl = nil then CreateEditControl;
  result := fEditControl.TextField;
end;
{$ENDIF}

{**********************************************}
function TALEdit.GetTextSettings: TTextSettings;
begin
  Result := FTextSettings;
end;

{************************************************************}
procedure TALEdit.SetTextSettings(const Value: TTextSettings);
begin
  FTextSettings.Assign(Value);
end;

{***********************************************}
procedure TALEdit.OnFontChanged(Sender: TObject);
begin
  if csLoading in componentState then exit;
  if FEditControl = nil then CreateEditControl;
  FEditControl.TextSettings.BeginUpdate;
  try
    FEditControl.TextSettings.IsChanged := True;
    FEditControl.TextSettings.Assign(ftextsettings);
  finally
    FEditControl.TextSettings.EndUpdate;
  end;
end;

{*********************************************}
procedure TALEdit.SetText(const Value: String);
begin
  if FEditControl = nil then CreateEditControl;
  FeditControl.Text := Value;
end;

{*******************************}
function TALEdit.getText: String;
begin
  if FEditControl = nil then CreateEditControl;
  result := FeditControl.Text;
end;

{*************************************}
function TALEdit.GetTextPrompt: String;
begin
  if FEditControl = nil then CreateEditControl;
  result := FeditControl.TextPrompt;
end;

{***************************************************}
procedure TALEdit.setTextPrompt(const Value: String);
begin
  if FEditControl = nil then CreateEditControl;
  FeditControl.TextPrompt := Value;
end;

{***********************************************}
function TALEdit.GetTextPromptColor: TAlphaColor;
begin
  if FEditControl = nil then CreateEditControl;
  {$IF defined(android) or defined(ios)}
  result := FeditControl.TextPromptColor;
  {$ELSE}
  result := fTextPromptColor;
  {$ENDIF}
end;

{*************************************************************}
procedure TALEdit.setTextPromptColor(const Value: TAlphaColor);
begin
  if FEditControl = nil then CreateEditControl;
  {$IF defined(android) or defined(ios)}
  FeditControl.TextPromptColor := Value;
  {$ELSE}
  fTextPromptColor := Value;
  {$ENDIF}
end;

{*****************************************}
function TALEdit.GetTintColor: TAlphaColor;
begin
  if FEditControl = nil then CreateEditControl;
  {$IF defined(ios)}
  result := FeditControl.TintColor;
  {$ELSE}
  result := fTintColor;
  {$ENDIF}
end;

{*******************************************************}
procedure TALEdit.setTintColor(const Value: TAlphaColor);
begin
  if FEditControl = nil then CreateEditControl;
  {$IF defined(ios)}
  FeditControl.TintColor := Value;
  {$ELSE}
  fTintColor := Value;
  {$ENDIF}
end;

{*************************************************************}
procedure TALEdit.SetKeyboardType(Value: TVirtualKeyboardType);
begin
  if FEditControl = nil then CreateEditControl;
  FeditControl.KeyboardType := Value;
end;

{*****************************************************}
function TALEdit.GetKeyboardType: TVirtualKeyboardType;
begin
  if FEditControl = nil then CreateEditControl;
  result := FeditControl.KeyboardType;
end;

{********************************************************************}
function TALEdit.GetAutoCapitalizationType: TALAutoCapitalizationType;
begin
  if FEditControl = nil then CreateEditControl;
  {$IF defined(ios)}
  result := FeditControl.AutoCapitalizationType;
  {$ELSE}
  result := fAutoCapitalizationType;
  {$ENDIF}
end;

{**********************************************************************************}
procedure TALEdit.setAutoCapitalizationType(const Value: TALAutoCapitalizationType);
begin
  if FEditControl = nil then CreateEditControl;
  {$IF defined(ios)}
  FeditControl.AutoCapitalizationType := Value;
  {$ELSE}
  fAutoCapitalizationType := Value;
  {$ENDIF}
end;

{**************************************************}
procedure TALEdit.SetPassword(const Value: Boolean);
begin
  if FEditControl = nil then CreateEditControl;
  FeditControl.Password := Value;
end;

{************************************}
function TALEdit.GetPassword: Boolean;
begin
  if FEditControl = nil then CreateEditControl;
  result := FeditControl.Password;
end;

{*******************************************************}
procedure TALEdit.SetCheckSpelling(const Value: Boolean);
begin
  if FEditControl = nil then CreateEditControl;
  FeditControl.CheckSpelling := Value;
end;

{*****************************************}
function TALEdit.GetCheckSpelling: Boolean;
begin
  if FEditControl = nil then CreateEditControl;
  result := FeditControl.CheckSpelling;
end;

{**************************************************************}
procedure TALEdit.SetReturnKeyType(const Value: TReturnKeyType);
begin
  if FEditControl = nil then CreateEditControl;
  FeditControl.ReturnKeyType := Value;
end;

{************************************************}
function TALEdit.GetReturnKeyType: TReturnKeyType;
begin
  if FEditControl = nil then CreateEditControl;
  result := FeditControl.ReturnKeyType;
end;

{***************************************************}
procedure TALEdit.SetMaxLength(const Value: integer);
begin
  if FEditControl = nil then CreateEditControl;
  FeditControl.MaxLength := Value;
end;

{*************************************}
function TALEdit.GetMaxLength: integer;
begin
  if FEditControl = nil then CreateEditControl;
  result := FeditControl.MaxLength;
end;

{******************************************************}
procedure TALEdit.OnChangeTrackingImpl(Sender: TObject);
begin
  if assigned(fOnChangeTracking) and (not (csLoading in componentState)) then
    fOnChangeTracking(self); // << yes need to send self instead of the fEditControl
end;

{************************************}
{$IF defined(ios) OR defined(android)}
procedure TALEdit.OnReturnKeyImpl(Sender: TObject);
begin
  if assigned(fOnReturnKey) and (not (csLoading in componentState)) then
    fOnReturnKey(self); // << yes need to send self instead of the fEditControl
end;
{$ENDIF}

{*************************************************}
{$IF (not defined(ios)) and (not defined(android))}
procedure TALEdit.OnKeyDownImpl(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (Key = vkReturn) and assigned(fOnReturnKey) and (not (csLoading in componentState)) then begin
    fOnReturnKey(self); // << yes need to send self instead of the fEditControl
    Key := 0;
  end;
end;
{$ENDIF}

{**********************************************************}
procedure TALEdit.SetOnReturnKey(const Value: TNotifyEvent);
begin
  if FEditControl = nil then CreateEditControl;
  fOnReturnKey := Value;
  {$IF defined(ios) OR defined(android)}
  if assigned(fOnReturnKey) then FEditControl.onReturnKey := OnReturnKeyImpl
  else FEditControl.onReturnKey := nil;
  {$ENDIF}
end;

{*********************************************}
procedure TALEdit.OnEnterImpl(Sender: TObject);
begin
  if assigned(fOnEnter) and (not (csLoading in componentState)) then
    fOnEnter(self); // << yes need to send self instead of the fEditControl
end;

{********************************************}
procedure TALEdit.OnExitImpl(Sender: TObject);
begin
  if assigned(fOnExit) and (not (csLoading in componentState)) then
    fOnExit(self); // << yes need to send self instead of the fEditControl
end;

{***********************************************}
procedure TALEdit.StrokeChanged(Sender: TObject);
var aRect: TrectF;
begin
  inherited StrokeChanged(Sender);
  if csLoading in componentState then exit;
  if FEditControl = nil then CreateEditControl;
  if Stroke.Kind = TbrushKind.None then fEditControl.Margins.Rect := TrectF.Create(0,0,0,0)
  else begin
    aRect := TrectF.Create(0,0,0,0);
    if (TSide.Top in Sides) then aRect.Top := Stroke.Thickness;
    if (TSide.bottom in Sides) then aRect.bottom := Stroke.Thickness;
    if (TSide.right in Sides) then aRect.right := Stroke.Thickness;
    if (TSide.left in Sides) then aRect.left := Stroke.Thickness;
    fEditControl.Margins.Rect := arect;
  end;
end;

{**********************************************}
procedure TALEdit.SetSides(const Value: TSides);
begin
  inherited SetSides(Value);
  StrokeChanged(nil);
end;

{************************************}
function TALEdit.GetCanFocus: Boolean;
begin
  {$IF defined(DEBUG)}
  ALLog('TALEdit.GetCanFocus', 'GetCanFocus', TalLogType.VERBOSE);
  {$ENDIF}
  if FEditControl = nil then CreateEditControl;
  result := inherited GetCanFocus;
  if result then begin
    {$IF defined(Android)}
    fEditControl.requestFocus;
    {$ELSE}
    fEditControl.SetFocus;
    {$ENDIF}
    exit(false);   // << the canparentfocus is also set to false, so the TCommonCustomForm.NewFocusedControl(const Value: IControl)
                   //    will do nothing !
  end;
end;

{****************************************}
function TALEdit.GetContainFocus: Boolean;
begin
  if FEditControl = nil then CreateEditControl;
  result := isFocused or FEditControl.IsFocused;
end;

{******************************}
Procedure TALEdit.AddNativeView;
begin
  if FEditControl = nil then CreateEditControl;
  {$IF defined(android) or defined(ios)}
  FeditControl.AddNativeView;
  {$ENDIF}
end;

{*********************************}
Procedure TALEdit.RemoveNativeView;
begin
  if FEditControl = nil then CreateEditControl;
  {$IF defined(android) or defined(ios)}
  FeditControl.RemoveNativeView;
  {$ENDIF}
end;

{**************************************************************************}
Procedure TALEdit.setSelection(const aStart: integer; const aStop: Integer);
begin
  if FEditControl = nil then CreateEditControl;
  {$IF defined(MSWINDOWS) or defined(_MACOS)}
  FeditControl.SelStart := aStart;
  FeditControl.SelLength := aStop - aStart;
  {$ELSEIF defined(android)}
  FeditControl.setSelection(aStart, aStop);
  {$ENDIF}
end;

{****************************************************}
Procedure TALEdit.setSelection(const aindex: integer);
begin
  if FEditControl = nil then CreateEditControl;
  {$IF defined(MSWINDOWS) or defined(_MACOS)}
  FeditControl.SelStart := aindex;
  {$ELSEIF defined(android)}
  FeditControl.setSelection(aindex);
  {$ENDIF}
end;

procedure Register;
begin
  RegisterComponents('Alcinoe', [TALEdit]);
end;

initialization
  RegisterFmxClasses([TALEdit]);

end.
