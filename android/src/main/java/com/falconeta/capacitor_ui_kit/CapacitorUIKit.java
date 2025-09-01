package com.falconeta.capacitor_ui_kit;

import com.getcapacitor.Logger;

public class CapacitorUIKit {

    public String echo(String value) {
        Logger.info("Echo", value);
        return value;
    }
}
