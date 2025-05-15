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

- in the profile tab, the update avatar options should be implemented (the user should be able to take a photo to replace their avatar, choose a photo, and delete the current photo if the avatar has a photo). change the delete button text to "Delete avatar photo". the delete button should be disabled if the user does not have a photo for their avatar (the user is simply using the devault avatar view).
- in the profile tab, we will eventually implement the change phone number feature to use our backend to change the authenticated phone number (lets mock this for the purpose of this mock project). created the necessary views and viewmodels (we should be using a view now instead of a sheet since we we will do phone number change verification)
- the gallery carousel is covering the flashing helper text. move the text higher so its not covered and make it smaller in font and also almost completly fade out in its animation.
- make the open photons button of the scanner a gallery icon instead and center it.
- pressing the open photos galery is displacing our qrscanner sheet and makeing it impossible to close it.
- the carousel gallery items should not have rounded cornders (check if there is some view extension or something that is still doing it). make the items have less space between them.
- contact state changes are not persisting as they should when the user changes the role or send a new ping (or does anyhing from the contact details sheet)
    - update the ping button to say pined and have a lighter blue background when the contact is curretly pinged.
- the respodners and dependents views are not updating when changes are made in the contact details sheet and the sheet is dismissed
- responders that sent you pings should not have the contact ping button set to pinged since they are the ones that pinged you (this button is only for pinging dependents)
- similar to how the contact details sheet shows that a dependent sent out an alert, there should also be a similar component of the sheet in the same place and style that shows when they are not responsive (description text and time ago). both should be able to appear at the same time if they have to.
- qrscanner x button does not work
- the pinged state of the contact details sheet ping button, has an issue with its blue background, it has a system gray background behind it. the blue background is not applying to the entire button as it should. use the "bell.and.waves.left.and.right.fill" when in this state
- remove the top app bar icons from the checkin view. lets rework the view. give me some variations. it only has three functions: shows the current time remaining, has the check-in button, has the manual alert button. app a button in the top app bar that lets me switch between the variations. we will eventually only pick one and delete the rest so keep that in mind.

## final touches to mvp:
- Fix and clean up our notification manager. local notifications are not showing. for instance, show a local notification that after showing does not get stored in the notification center of the phone (its meant to act like an app toast)
    - show a local notification when the user toggles a contact’s role
    - show a local notification when a user sends a ping (instead of the alert box that we currently have)
    - show a local notification for when the user checks in.
- migrate over the manual alert button from the production application
- update our dependents list sorter
- add haptic feedback to all interactions
- make the home qr code smaller and add a white background that has some passing and rounder corners. make the grey background they sit on have consistent padding on all sides. 
