import ij.plugin.PlugIn;
import org.python.util.PythonInterpreter;
public class IJOctopus implements PlugIn {
  public void run(String arg) {
    // create a Python interpreter
    PythonInterpreter py = new PythonInterpreter();
    // execute the IJOctopus code
    py.execfile("~/GitHub/impy-tools/IJ_Octopus/IJOctopus_.py");
  }
}