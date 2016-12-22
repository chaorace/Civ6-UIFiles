-------------------------------------------------
-- touch screen number pad
-------------------------------------------------

-------------------------------------------------
-------------------------------------------------
function OnOK()
    UI.PostKeyMessage( 13 ); -- enter
end
Controls.OKButton:RegisterCallback( Mouse.eLClick, OnOK );

-------------------------------------------------
-------------------------------------------------
function OnBackspace()
    UI.PostKeyMessage( 8 ); -- backspace
end
Controls.BackspaceButton:RegisterCallback( Mouse.eLClick, OnBackspace );

-------------------------------------------------
-------------------------------------------------
function OnKey( number )
    UI.PostKeyMessage( 48 + number ); -- '0' + void1
end
Controls.Button1:RegisterCallback( Mouse.eLClick, OnKey );
Controls.Button2:RegisterCallback( Mouse.eLClick, OnKey );
Controls.Button3:RegisterCallback( Mouse.eLClick, OnKey );
Controls.Button4:RegisterCallback( Mouse.eLClick, OnKey );
Controls.Button5:RegisterCallback( Mouse.eLClick, OnKey );
Controls.Button6:RegisterCallback( Mouse.eLClick, OnKey );
Controls.Button7:RegisterCallback( Mouse.eLClick, OnKey );
Controls.Button8:RegisterCallback( Mouse.eLClick, OnKey );
Controls.Button9:RegisterCallback( Mouse.eLClick, OnKey );
Controls.Button0:RegisterCallback( Mouse.eLClick, OnKey );
