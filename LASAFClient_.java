import ij.IJ;
import ij.gui.GenericDialog;
import ij.plugin.PlugIn;
import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.LineNumberReader;
//import java.io.OutputStream;
import java.io.PrintWriter;
import java.net.Socket;
import java.net.UnknownHostException;

public class LASAFClient_ implements PlugIn
{
	public void run(String arg)
	{
		// Default path of the script file
		String defaultfilepath="C:\\CAMscript.txt";
		// Default address of the LASAF server
		String defaultserverip="0.0.0.0";
		int defaultserverport=0;
		
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
		BufferedReader in = null;
		String fromUser;
        String fromServer;
        boolean test;
        int cnt=0;
        
        try {	
            CAMSocket = new Socket(serverip, serverport);
            //OutputStream out = CAMSocket.getOutputStream(); // !!!! ORIGINAL LINE !!!! //
            PrintWriter out = new PrintWriter(CAMSocket.getOutputStream(), true);
            in = new BufferedReader(new InputStreamReader(CAMSocket.getInputStream(),"UTF-8"));
            
            FileInputStream FileStream = new FileInputStream(filepath);
            InputStreamReader FileAdapt = new InputStreamReader(FileStream);
            LineNumberReader Data = new LineNumberReader(FileAdapt);
            
            // Wait for a server answer (full line)
           	fromServer = in.readLine();
           	IJ.log("Server answer: "+fromServer);
           	
           	fromUser = Data.readLine();
           	while( fromUser != null && fromUser.length() >4)
           	{	
          		//out.write(fromUser.getBytes());  // !!!! ORIGINAL LINE !!!! //
          		out.println(fromUser);
          		
           		IJ.log("Sent("+cnt+")"+fromUser);
          		//fromServer = in.readLine();
          		//IJ.log("Answered: "+fromServer);
           		
           		try {
           			Thread.sleep(200);
           		} catch(InterruptedException e) {
           		} 
           		
           		fromUser=Data.readLine();
           		cnt++;
           	}	
        	
           	IJ.log("CAMscript successfully sent, waiting for -scanfinished-...");
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
