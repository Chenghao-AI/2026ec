importPackage(Packages.com.ti.debug.engine.scripting);
importPackage(Packages.com.ti.ccstudio.scripting.environment);
importPackage(Packages.java.lang);

var ccxmlFile =
    "C:/Users/24307/Desktop/final/empty_LP_MSPM0G3507_nortos_ticlang/targetConfigs/MSPM0G3507.ccxml";
var programFile =
    "C:/Users/24307/Desktop/final/empty_LP_MSPM0G3507_nortos_ticlang/Debug/empty_LP_MSPM0G3507_nortos_ticlang.out";

var script = ScriptingEnvironment.instance();
var debugServer = null;
var debugSession = null;
var targetConnected = false;
var programLoaded = false;
var targetHalted = false;
var testPassed = false;

try {
    script.setScriptTimeout(120000);
    debugServer = script.getServer("DebugServer.1");
    debugServer.setConfig(ccxmlFile);

    /* Select only the Cortex-M0+ CPU. Never open CS_DAP_0 or SEC_AP. */
    debugSession = debugServer.openSession(".*CORTEX_M0P");
    debugSession.target.connect();
    targetConnected = true;

    print("CONNECTED CPU=" + debugSession.getCPUName() +
          " PART=" + debugSession.getPartnum());

    /* Refuse to program unless CCS supports full verification after load. */
    if (!debugSession.options.optionExist("VerifyAfterProgramLoad")) {
        throw new Error("VerifyAfterProgramLoad option is unavailable; refusing to program");
    }

    debugSession.options.setString(
        "VerifyAfterProgramLoad", "Full verification");

    if (debugSession.options.optionExist("AutoRunToLabelOnRestart")) {
        debugSession.options.setBoolean("AutoRunToLabelOnRestart", false);
    }
    if (debugSession.options.optionExist("AddCIOBreakpointAfterLoad")) {
        debugSession.options.setBoolean("AddCIOBreakpointAfterLoad", false);
    }
    if (debugSession.options.optionExist("AddCEXITbreakpointAfterLoad")) {
        debugSession.options.setBoolean("AddCEXITbreakpointAfterLoad", false);
    }

    print("PROGRAM_LOAD_BEGIN");

    /* The only program/Flash operation in this script. No retry is present. */
    debugSession.memory.loadProgram(programFile);
    programLoaded = true;

    print("PROGRAM_LOAD_AND_VERIFY_OK");

    debugSession.target.restart();
    debugSession.target.runAsynch();
    Thread.sleep(500);
    debugSession.target.halt();
    targetHalted = true;

    var keyValue = Number(debugSession.expression.evaluate("key_value"));
    print("WATCH key_value=" + keyValue);

    if (keyValue !== 16) {
        throw new Error("Expected key_value=16, observed " + keyValue);
    }

    testPassed = true;
    print("HARDWARE_TEST_PASS key_value=16");
} catch (error) {
    print("HARDWARE_TEST_FAILED: " + error);
} finally {
    if (debugSession !== null && targetConnected) {
        /* Leave a successfully programmed target running after observation. */
        if (programLoaded && targetHalted) {
            try {
                debugSession.target.runAsynch();
                targetHalted = false;
            } catch (runError) {
                print("TARGET_RESUME_WARNING: " + runError);
                testPassed = false;
            }
        }

        try {
            debugSession.target.disconnect();
            targetConnected = false;
        } catch (disconnectError) {
            print("DSS_DISCONNECT_WARNING: " + disconnectError);
            testPassed = false;
        }
    }

    if (debugSession !== null) {
        try {
            debugSession.terminate();
        } catch (terminateError) {
            print("DSS_TERMINATE_WARNING: " + terminateError);
            testPassed = false;
        }
    }

    if (debugServer !== null) {
        try {
            debugServer.stop();
        } catch (stopError) {
            print("DSS_STOP_WARNING: " + stopError);
            testPassed = false;
        }
    }
}

if (testPassed) {
    print("RESULT=PASS");
} else {
    print("RESULT=FAIL");
}
