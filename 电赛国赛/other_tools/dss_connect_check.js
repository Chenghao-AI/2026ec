importPackage(Packages.com.ti.debug.engine.scripting);
importPackage(Packages.com.ti.ccstudio.scripting.environment);
importPackage(Packages.java.lang);

var ccxmlFile =
    "C:/Users/24307/Desktop/final/empty_LP_MSPM0G3507_nortos_ticlang/targetConfigs/MSPM0G3507.ccxml";

var script = ScriptingEnvironment.instance();
var debugServer = null;
var debugSession = null;
var exitCode = 1;

try {
    script.setScriptTimeout(30000);
    debugServer = script.getServer("DebugServer.1");
    debugServer.setConfig(ccxmlFile);
    debugSession = debugServer.openSession(".*CORTEX_M0P");

    /* Connection check only: no program load, erase, flash, reset, or run. */
    debugSession.target.connect();
    print("DSS_CONNECT_OK");
    print("CPU=" + debugSession.getCPUName());
    print("PART=" + debugSession.getPartnum());
    exitCode = 0;
} catch (error) {
    print("DSS_CONNECT_FAILED: " + error);
} finally {
    if (debugSession !== null) {
        try {
            debugSession.target.disconnect();
        } catch (disconnectError) {
            print("DSS_DISCONNECT_WARNING: " + disconnectError);
            exitCode = 1;
        }

        try {
            debugSession.terminate();
        } catch (terminateError) {
            print("DSS_TERMINATE_WARNING: " + terminateError);
            exitCode = 1;
        }
    }

    if (debugServer !== null) {
        try {
            debugServer.stop();
        } catch (stopError) {
            print("DSS_STOP_WARNING: " + stopError);
            exitCode = 1;
        }
    }
}

System.exit(exitCode);
