## Development cycle

### architecture guidelines from context 7 and reasoning

### architecture specification from guidelines, user experience, mock application, and _

### mock from current user experience and non-live implementation architecture guidelines
- TODO: create a mock architecture guidelines for ios, backend, and android
    - Remove TCA dependencies and replace with vanilla SwiftUI
    - Use mock data where needed

### user experience from reasoning and current mock



## Guidelines
- naming convernsions
- replace our agnostic infrastructure guidelines with domain driven design’s anti-coruption layer guidelines

## Application Specification
- 



## Prompts

### Feature implementation or update
- update our mock app at @Architecture/iOS/ApplicationSpecification/MockApplication/MockApplication/Features/QRCodeSystem with absolute truth reference to our production app @iOSApplication/LifeSignal/LifeSignal/Features/QRCodeSystem. the folders and file names should match it exactly (there shouldn't be missing files nor extra files). breakdown the folders and files structure during planning. feel free to look around in the production app's structure:





## Migration from Production App to Mock App

- This is part of an ongoing migration
- Our MVP production code (`@iOSApplication/LifeSignal/LifeSignal`) is currently messy. We need to create mock versions (view models) in our mock app (`@Architecture/iOS/ApplicationSpecification/MockApplication/MockApplication`) for the respective views.
- The production folder structure, views, and feature pairings are correct.

#### TODOs:

1. **Create a comprehensive migration plan**:
   - List all directories, files, and file operations.
   - Ensure there are no missing or extra files.

2. **Create mock view models**:
   - Each view must have its own mock view model.
   - Use vanilla Swift (not TCA).
   - Structure these mock view models in a way that supports future TCA migration.
   - Be aware that many features in the production app are expected but not yet implemented.
   - Likewise, many view models in the mock app are expected but not implemented.

3. **Mirror the production structure**:
   - Replicate the production app's file structure in `@Architecture/iOS/ApplicationSpecification/MockApplication/MockApplication/App` using vanilla Swift.
   - Design it so it transitions smoothly into TCA features.

4. **Ignore infrastructure folders**:
   - Ignore both `@iOSApplication/LifeSignal/LifeSignal/Core/Infrastructure` and `@iOSApplication/LifeSignal/LifeSignal/Infrastructure`.

5. **Evaluate `contactsManualAlert`**:
   - It's not implemented.
   - Determine what functionality needs to be migrated to it.

6. **Update the application specification**:
   - After completing the mock migration, update `@Architecture/iOS/ApplicationSpecification` accordingly.
   
   
   
   

## mock refactoring
- give me a plan for a more consistent mock application folder and files structure

- make the layout of our ui more consistent between views so we can easily copy and paste sections of different views




# Pending Features

- in the profile tab, remove the option to take a photo for the update avatar.
- pressing the open photos galery is displacing our qrscanner sheet and makeing it impossible to close it.
- responders that sent you pings should not have the contact ping button set to pinged since they are the ones that pinged you (this button is only for pinging dependents). we should have two different types of pings for data (incoming from responders and outgoing to dependents)
- qrscanner x button does not work
- the send verification code button should be disabled until the phone number entered is in a valid format. this also goes for the verification code (its a 6 digit code. we should display it in this format when entered: XXX-XXX)
- remove the opage background from the x button in the qrscanner and from the fadding text above the photos carousel. make the open gallery button below the carousel be in pill form with its current backround. add a little more padding at the botom so the button is not so close to the edge. 
- instead of the alert dialog box that shows. we should be taking the user to the add contact sheet so they can add the contact if they wish to.
- the responders tab icon still shows a badge after i cleared all the pings from the responders view. either the badge is not updating or there is some state issue there (the ping icons are cleared successfully in the responders view). could this be the same contacts state issue that we have with the contacts details sheet?
- sign out button in the profile tab should sign out the user and navigate back to the sign in view.
- sending a ping to dependents contact that is not responsive does not update the state. there is a systemic issue here with the state changes of a contact. find out what it is and fix it.
- we should be able to stack badges in the dependents view avatar (alert at the top, not responsive next, and ping last). make sure this follows good ui principles for stacked badges on avatars
- for check in view variations, do not show seconds (only days, hours, minutes). remove the minimal view. in the vertical view, move the alert button directly below the counter (do the same in the circular view). move the check in button to the bottom of the view for both. generate two move variations that we will review
- some tab views seem to have some padding at the bottom of the views. find it and remove it
- add a confirmation alert for role toggle in contact details sheet


- remove the alert and warning badges from the dependents view cards, use icons with a system background circle instead (placed to the right end of the card). it should be the same size as the avatar
- the check-in interval display values are inconsistent, fix it (sometimes it shows days for when we have hours selected)
- add a description to the contact details sheet sent out an alert component. check the not responsive info component for reference


- update the shared qr code to look like our implementation in our production app with the formatting we added to the image. use the production app for reference only @iOSApplication


## final touches to mvp:
- Fix and clean up our notification manager. local notifications are not showing. for instance, show a local notification that after showing does not get stored in the notification center of the phone (its meant to act like an app toast)
    - show a local notification when the user toggles a contact’s role
    - show a local notification when a user sends a ping (instead of the alert box that we currently have)
    - show a local notification for when the user checks in.
    - show a local notification for successfully changing the phone number
- migrate over the manual alert button from the production application
- update our dependents list sorter
- add haptic feedback to all interactions
- make the home qr code smaller and add a white background that has some passing and rounder corners. make the grey background they sit on have consistent padding on all sides. 
