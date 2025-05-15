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
- make a notification preference view used instead of the current check in reminder.
- add a toggle all notifications view and view model with confirmation dialog and notification change feedback that dismisses itself
- make our mock qrscanner (@Architecture/iOS/ApplicationSpecification/MockApplication/MockApplication/UI/QRCodeSystem) UI and ux be exactly like our production app's (@Architecture/iOSApplication/LifeSignal/LifeSignal/Features/QRCodeSystem) ui and ux. copy the same folder and file structure

- we need to add permissions for the image gallery sheet and the recent images carousel of the qr scanner in the plist


- responder cards should never turn red like dependent cards do (since this functionality is strictly a dependents list functionality)
- pressing the ping icon in the responder card should not clear the ping. We don’t need that feature
- the respond to all button in the responders view should be like a grayed out blue when inactive
- share qr code should always be an image (not "Any" so the user has the option to save to gallery)

- show a alert icon (exclamationmark.octagon) next to a dependent that has sent out a manual alert (just like how we show a ping icon). Make it flash. This state of the card take precedence over warning and ping states.
- show a triangle warning icon (similar in style to the ping icon we show) next to a dependent that is not responsive (just like how we show a ping icon)
- show a silent local notification when the user toggles a contact’s role
- show a local notification when a user sends a ping (instead of the alert box that we currently have)
- use a “bell.badge.fill” icon for responder cards that sent the user a ping instead of the current icon
- use a “person.crop.circle.dashed” icon for the profile tab icon
- update the checkin tab bar logo to use “iphone” icon
- move alert to responders to the top of check in screen
- remove the check-in interval and check in interval, last checked in, and next check in data section of the check in screen
- check in now button should not have a leading icon and have the label “Check-in Now”
