# LifeSignal iOS UI Guidelines

**Navigation:** [Back to Application Specification](../README.md)

---

## Overview

This document provides comprehensive UI guidelines for the LifeSignal iOS application, including design system implementation, navigation patterns, accessibility requirements, and animation guidelines.

## Design System

### Colors

The LifeSignal application uses a consistent color palette based on the system colors with custom accent colors for specific states:

#### Background Colors

- **Primary Background**: `systemGroupedBackground` - Used for screen backgrounds
- **Secondary Background**: `secondarySystemGroupedBackground` - Used for card backgrounds
- **Tertiary Background**: `tertiarySystemGroupedBackground` - Used for elements within cards

#### Content Colors

- **Primary Text**: `label` - Used for primary text content
- **Secondary Text**: `secondaryLabel` - Used for secondary text content
- **Tertiary Text**: `tertiaryLabel` - Used for tertiary text content

#### Accent Colors

- **Primary Accent**: `blue` - Used for primary buttons and active elements
- **Alert Color**: `red` - Used for alerts and error states
- **Warning Color**: `yellow` - Used for warnings and non-responsive states
- **Success Color**: `green` - Used for success states

### Typography

The LifeSignal application uses the system fonts with consistent text styles:

#### Text Styles

- **Large Title**: Used for screen titles
- **Title 1**: Used for section titles
- **Title 2**: Used for card titles
- **Title 3**: Used for element titles
- **Headline**: Used for emphasized content
- **Body**: Used for regular content
- **Callout**: Used for callout content
- **Subheadline**: Used for secondary content
- **Footnote**: Used for tertiary content
- **Caption 1**: Used for small labels
- **Caption 2**: Used for very small labels

### Layout

The LifeSignal application uses consistent layout patterns:

#### Spacing

- **Extra Small**: 4 points
- **Small**: 8 points
- **Medium**: 16 points
- **Large**: 24 points
- **Extra Large**: 32 points

#### Margins

- **Screen Margins**: 16 points
- **Card Margins**: 16 points
- **Element Margins**: 8 points

#### Padding

- **Card Padding**: 16 points
- **Element Padding**: 8 points

### Components

The LifeSignal application uses a consistent set of UI components:

#### Buttons

- **Primary Button**: Blue background, white text, rounded corners
- **Secondary Button**: Clear background, blue text, rounded corners
- **Alert Button**: Red background, white text, rounded corners
- **Disabled Button**: Gray background, white text, rounded corners

Button styles:
- Disable default opacity changes that occur on tap or hold
- Add haptic feedback to all button interactions

#### Cards

- **Standard Card**: White background, rounded corners, subtle shadow
- **Alert Card**: Red background, white text, rounded corners, subtle shadow
- **Warning Card**: Yellow background, dark text, rounded corners, subtle shadow

#### Text Fields

- **Standard Text Field**: White background, rounded corners, subtle border
- **Error Text Field**: White background, red border, rounded corners

#### Avatars

- **Standard Avatar**: Circular, 40x40 points
- **Large Avatar**: Circular, 80x80 points
- **Small Avatar**: Circular, 24x24 points

#### Icons

- **Standard Icon**: 24x24 points
- **Large Icon**: 32x32 points
- **Small Icon**: 16x16 points

## Navigation

### Tab Navigation

The LifeSignal application uses a tab bar for primary navigation:

- **Home Tab**: Displays the home screen with check-in and alert functionality
- **Contacts Tab**: Displays the contacts screen with responders and dependents
- **Notifications Tab**: Displays the notifications screen
- **Profile Tab**: Displays the profile screen

Tab bar appearance:
- Background should be visible when elements are underneath it
- Use standard system tab bar appearance

### Modal Navigation

The LifeSignal application uses modal presentations for specific flows:

- **Authentication**: Presented modally over the main application
- **Onboarding**: Presented modally after authentication
- **QR Scanner**: Presented modally for scanning QR codes
- **Contact Details**: Presented modally for viewing contact details
- **Settings**: Presented modally for viewing and editing settings

Modal appearance:
- Use standard system modal presentation style
- Include a close button for dismissal

### Push Navigation

The LifeSignal application uses push navigation for hierarchical content:

- **Contact List to Contact Details**: Push navigation
- **Notification List to Notification Details**: Push navigation
- **Settings to Specific Setting**: Push navigation

Push navigation appearance:
- Use standard system navigation bar appearance
- Include a back button with the label "Back"

### Swipe Navigation

The LifeSignal application uses swipe gestures for specific interactions:

- **Swipe to Dismiss**: Used for dismissing modal presentations
- **Swipe to Delete**: Used for deleting items in lists
- **Swipe to Refresh**: Used for refreshing content

## Accessibility

### Text Size

The LifeSignal application supports Dynamic Type for text size adaptation:

- All text should use Dynamic Type text styles
- Layouts should adapt to different text sizes
- Minimum supported text size: xSmall
- Maximum supported text size: xxxLarge

### Voice Over

The LifeSignal application supports Voice Over for screen reading:

- All UI elements should have appropriate accessibility labels
- All images should have appropriate accessibility descriptions
- All actions should have appropriate accessibility hints
- Navigation should be logical and intuitive

### Reduced Motion

The LifeSignal application supports Reduced Motion for users sensitive to motion:

- Animations should be disabled when Reduced Motion is enabled
- Essential animations should be simplified when Reduced Motion is enabled
- No flashing content that could trigger seizures

### Color Contrast

The LifeSignal application supports high contrast for users with visual impairments:

- All text should have a minimum contrast ratio of 4.5:1
- All UI elements should have a minimum contrast ratio of 3:1
- Support for Dark Mode to improve visibility in low-light conditions

## Animations

### Transition Animations

The LifeSignal application uses consistent transition animations:

- **Screen Transitions**: Standard system transitions
- **Modal Presentations**: Standard system modal transitions
- **Push Navigation**: Standard system push transitions

### Feedback Animations

The LifeSignal application uses animations for user feedback:

- **Button Press**: Subtle scale animation
- **Error Shake**: Horizontal shake animation for error states
- **Success Pulse**: Subtle pulse animation for success states

### Progress Animations

The LifeSignal application uses animations to indicate progress:

- **Loading Spinner**: Standard system activity indicator
- **Progress Bar**: Linear progress bar for determinate progress
- **Check-In Countdown**: Circular progress indicator for check-in countdown

### Alert Animations

The LifeSignal application uses animations for alert states:

- **Alert Activation**: Rectangle animation filling 25% of button width with each tap
- **Alert Deactivation**: 3-second hold with animation expanding from center to edges
- **Active Alert**: Flashing red background animation for active alerts

## Dark Mode

The LifeSignal application fully supports Dark Mode:

- All UI elements should adapt to Dark Mode
- Custom colors should have Dark Mode variants
- Images should have Dark Mode variants where appropriate
- Contrast should be maintained in Dark Mode

## Responsive Design

The LifeSignal application supports all iPhone screen sizes:

- Layouts should adapt to different screen sizes
- UI elements should scale appropriately
- Content should be readable on all screen sizes
- Minimum supported screen size: iPhone SE (1st generation)
- Maximum supported screen size: iPhone Pro Max

## Specific UI Requirements

### Home Screen

- Check-in button should be blue, positioned at bottom, twice the height of alert button
- Alert button should have rectangle animation filling 25% of button width with each tap
- Alert deactivation requires 3-second hold with animation expanding from center to edges
- Countdown should show only two highest time units (days, hours, minutes, seconds)

### Contacts Screen

- Responders and dependents should be displayed in separate tabs
- Contacts should be displayed in a list with avatars and status indicators
- Non-responsive contacts should have yellow backgrounds
- Contacts with active alerts should have red backgrounds (with flashing animation)
- Dependent sorting options: Time left, Name, Date added

### Notification Screen

- Notifications should be displayed in a list with icons and timestamps
- Notification filters: All, Alerts, Pings, Roles, Contacts, Check-Ins
- Notification center button should be in top app bar using bell.square.fill icon
- Unread notifications should be indicated with a badge

### Profile Screen

- Profile information should be displayed in a card with avatar and name
- QR code should span full width with proper padding (16 horizontal)
- QR code ID should be displayed at bottom for manual entry
- Emergency note should be displayed in a card with edit button

### Authentication Screen

- Phone number field should have placeholder format with 'X' characters
- Verification code field should have placeholder format with 'X' characters
- Continue button should be disabled until all fields are completed
- Error messages should be displayed below the relevant field

### Onboarding Screen

- First and last name fields should be separate with proper capitalization
- Continue button should be disabled until all fields are completed
- Progress indicator should show current step in the onboarding process
- Back button should be available to return to previous steps

## Implementation Guidelines

When implementing UI for the LifeSignal iOS application, follow these guidelines:

1. Use SwiftUI for all new UI development
2. Use TCA's WithPerceptionTracking for UI updates
3. Use standard system components where possible
4. Follow the design system for colors, typography, and layout
5. Ensure accessibility support for all UI elements
6. Test on multiple device sizes and in both light and dark mode
7. Implement proper error handling and loading states
8. Add haptic feedback to all interactions except focus of field texts
9. Make the home view scrollable with bottom tab bar background visible when elements are underneath it
10. Use consistent positioning of avatars and text in cards

## UI Testing

The LifeSignal iOS application should be tested for UI consistency and accessibility:

1. Test on all supported device sizes
2. Test in both light and dark mode
3. Test with different text sizes
4. Test with Voice Over enabled
5. Test with Reduced Motion enabled
6. Test with high contrast enabled
7. Test with different color schemes
8. Test with different language settings
9. Test with different region settings
10. Test with different time zone settings
