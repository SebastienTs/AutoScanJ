import ij.IJ;
import ij.gui.GenericDialog;
import ij.plugin.PlugIn;
import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.LineNumberReader;
import java.io.OutputStream;
import java.net.Socket;
import java.net.UnknownHostException;

public class LASAFClient_ implements PlugIn
{
	public void run(String arg)
	{
		// Default path of the script file
		String defaultfilepath="C:\\CAMscript.txt";
		// Default address of the LASAF server
		String defaultserverip="10.5.85.21";
		int defaultserverport=8895;
		
		// Parameters panel
		GenericDialog gd = new GenericDialog("LASAF matrix screener communication client");
		gd.addStringField("filepath", defaultfilepath);
		gd.addStringField("serverip", defaultserverip);
		gd.addNumericField("serverport", defaultserverport, 0);
        gd.showDialog();
		if (gd.wasCanceled())
        return;
		String filepath = gd.getNextString();
		String serverip = gd.getNextString();
		int serverport = (int)gd.getNextNumber();
		
		IJ.log("Full path to the script to send: "+filepath+"\n");
		IJ.log("Server IP: "+serverip+"\n");
		IJ.log("Server Port: "+serverport+"\n");
		
		// Initialization
		Socket CAMSocket = null;
		BufferedReader 	in = null;
        byte[] theByteArray = null;
        String fromUser;
        String fromServer;
        boolean test;
        
        try {	
            CAMSocket = new Socket(serverip, serverport);
            OutputStream out = CAMSocket.getOutputStream();       
            in = new BufferedReader(new InputStreamReader(CAMSocket.getInputStream()));
            
            FileInputStream FileStream = new FileInputStream(filepath);
            InputStreamReader FileAdapt = new InputStreamReader(FileStream);
            LineNumberReader Data = new LineNumberReader(FileAdapt);
            
           	while (in.readLine() == null)
           	{
           		// Wait for the server response (Welcome message)
           	}
        			
           	fromUser = Data.readLine();
           	while( fromUser != null && fromUser.length() >4)
           	{	
           		theByteArray = fromUser.getBytes();
           		out.write(theByteArray);
           		IJ.log("Sent: "+fromUser+"\nAnswered: "+in.readLine()); // blocking statement
           		fromUser=Data.readLine();
           	}	
        	
           	test = false;
           	while(test==false)
           	{
           		fromServer = in.readLine();
           		test = fromServer.indexOf("scanfinished") > 0;
           	}	
           	
           	// Close all resources
       		out.close();
        	in.close();
        	CAMSocket.close();
        	Data.close();
        	FileStream.close();
     
        } catch (UnknownHostException e) {
            IJ.error("Don't know about host: "+serverip);
        } catch (IOException e) {
        	IJ.error("Couldn't get I/O for the connection to: "+serverip+" and/or to the script file "+filepath);
        }
		
	}
	
}
