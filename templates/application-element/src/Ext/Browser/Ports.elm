port module Ext.Browser.Ports exposing (..)

import Ext.Browser exposing (Location)


port pushUrl : ( Float, String ) -> Cmd msg


port replaceUrl : ( Float, String ) -> Cmd msg


port back : ( Float, Int ) -> Cmd msg


port forward : ( Float, Int ) -> Cmd msg


port onLocationChange : (Location -> msg) -> Sub msg


port onLocationRequest : (( Location, Location ) -> msg) -> Sub msg
