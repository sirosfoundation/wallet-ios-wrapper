# Xcode-Cloud Setup Guide

## Prerequisites

- A Mac computer with a relatively recent macOS
- A recent Xcode
- Apple Developer ID connected to SIROS' Apple company account
- Access to appstoreconnect.apple.com for SIROS
- An app entry in App Store Connect matching the project
- Github account with access to the respective project

## Steps

- Check out the respective project on your Mac.
- Open its `xcodeproj` folder in Xcode.
- Under Settings -> Apple Accounts sign in to your developer account. 
  Make sure it belongs to the "STIFT SIROS FOUNDATION" team.
- Open the "Reports" navigator pane on the left side. (View -> Navigators -> Reports)
- Click the "Cloud" tab inside the "Reports" navigator pane.
- Hit the "Get Started…" button and make sure your app and the respective developer team 
  is set. Click "Next".
- Xcode will analyze the source repositories. Only "Connect" your repository, not that of
  any dependencies.
- Xcode will jump you into a webbrowser to appstoreconnect.apple.com.
- App Store Connect might show you a list of dependency repositories and tell you that
  all of them are necessary to connect. That is actually not true.
- Press the button to continue on Github. Select the SIROS Foundation organisation and
  the repository of the respective project. Click "Update access". (Or "Install & Request"
  if Xcode Cloud access was removed from other projects in the meantime.)
- Finish the flow. You might need better access to the Github project. Ask your manager.
- When successful, Xcode should now show the repository as connected. Continue.
- Xcode will show the matching app on App Store Connect, if set up correctly. Continue.
- You then should see a "Branch" and "Workflow" selection page. You can modify these later,
  so it's fine to keep the defaults for now. Hit "Close".
- In the "Reports/Cloud" pane you should now see your app's name and a "Default" workflow.
- Right click the "Default" workflow and select "Edit Workflow…"
- Now you can configure the workflow as you like and add more.

## Advanced Configuration

- The default workflow only shows a "Build" action. Note, that there are others: "Test", 
  "Analyze" and "Archive". 
  - To run tests automatically after build, add/replace with the "Test" action.

- A typical scenario is to automatically push builds to TestFlight when a release tag was set.
  You can achieve that with a "Tag Changes" start condition, an "Archive" action and a
  "TestFlight External/Internal" post-action. Put that in its own workflow.
  
  NOTE: Xcode Cloud will use its own credentials for signing. You don't have to worry about
  these.
  
## Custom Build Scripts

You can have custom shell build scripts located under `${PROJECT_DIR}/ci_scripts/`.
The environment variables you define in a workflow under "Environment" will be available 
in your scripts.

Follow [this guide](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts) 
on how to do that.

Note for clarification: expect the `PWD` in the build scripts to be the `ci_scripts` directory.

## Hints

- Despite the documentation saying otherwise, `xcconfig` files are fine in Xcode Cloud.
  You might want to create/edit them in a `ci_post_clone.sh` script with (shared)
  environment variables, though.
  
- Despite your best efforts to control `CURRENT_PROJECT_VERSION` (the build number), 
  it *will* be overwritten by what Xcode Cloud thinks is best. 
  (Which is a monotonous counter starting at 1.)
  If you had (semi-)manual releases before, there's unfortunately no way to control the
  output of the "Archive" action. You will need to let Xcode Cloud do as many (test) builds,
  as you had before, or be fine with lower build numbers for releases.
  
- You can review and edit build settings and workflows online at 
  [App Store Connect](https://appstoreconnect.apple.com/teams/69a6de88-adb8-47e3-e053-5b8c7c11a4d1/xcode-cloud/products),
  but you *cannot* add a new project to Xcode Cloud. You will need a Mac and Xcode for that.
  
- When you configure to do a build on pull requests, the results will show up in Github PRs.

## Pros/Cons to Github Actions

+ No issues with ever-changing build machines. Xcode Cloud will use the right configuration.
+ No issues with uploading to App Store Connect. Everything happens on Apple's machines already.
+ Much faster.

- Some manual configuration is needed to start off.
- Besides `ci_scripts`, configuration is stored on Apple servers, not in the Github project.

## Further Reading

https://developer.apple.com/documentation/Xcode/Xcode-Cloud/
https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow
https://developer.apple.com/documentation/xcode/setting-up-your-project-to-use-xcode-cloud

## Reference Project

https://github.com/sirosfoundation/wallet-ios-wrapper

## Author

Benjamin Erhart <berhart@netzarchitekten.com>