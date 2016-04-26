### How to use **Build Notification** Task

This extension contains a build task for VS Team Services to Send Custom Email Build Notifcation for vNext builds.

1.After installing the extension, upload your project to VSO.

2.Go to your VSO project, click on the Build tab, and create a new Build definition.

3.Click Add tasks and select "Build Notification" from the Utility category.

4.Configure the step.

###Input the following 2 Variables under the variables tab:

   MailAccount Password(MailAccntPWD)   -- Prefered Encrypted Format 
   Personal Access Token(PAT)           -- Prefered Encrypted Format

###Input the following values for the Task:

	From
	To (Comma-Delimitied)
	Cc (Comma-Delimitied)
	BCc (Comma-Delimitied)
	SMTPServer
	BannerHeader
	MailAccountPWD (Better we suggest to use the Encrypted value from Variable section($(MailAccntPWD)) )
	PAT (Better we suggest to use the Encrypted value from Variable section($(PAT)) )

###Trigger a build will get the Notification email for VNext Build.
