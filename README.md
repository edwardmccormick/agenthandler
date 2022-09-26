# Introduction 
TODO: This project is designed to be a script running at the end of a AzureDevOps Build Process. If there are builds queued, the script should keep the current agent running. If there is a job running on this particular agent that has not finished, it should keep the current agent running. If there are no jobs running on the current agent, it should shut the agent down.

# Getting Started
TODO: Guide users through getting your code up and running on their own system. In this section you can talk about:
1.	The extension can be installed on any build host *that has Powershell installed and AWS Powershell Tools*
2.	To test locally, uncomment out the lines that describe running locally, and comment out the "ENV:" variables
3.	Latest releases
4.	API references

# Build and Test
TODO: Describe and show how to build your code and run the tests. 

# Contribute
TODO: Explain how other users and developers can contribute to make your code better. 

If you want to learn more about creating good readme files then refer the following [guidelines](https://docs.microsoft.com/en-us/azure/devops/repos/git/create-a-readme?view=azure-devops). You can also seek inspiration from the below readme files:
- [ASP.NET Core](https://github.com/aspnet/Home)
- [Visual Studio Code](https://github.com/Microsoft/vscode)
- [Chakra Core](https://github.com/Microsoft/ChakraCore)

277105 - Updating start and stop AWS EC2 Host scripts