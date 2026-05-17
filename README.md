# Presenza (camsvirtusa)

Presenza is a **Flutter + Firebase college attendance management system** built for three major user roles:

- **Student**
- **Faculty**
- **Admin**

The application uses **Bluetooth Low Energy (BLE)** for classroom attendance signaling and **Cloud Firestore** as the real-time source of truth for data such as users, class mappings, sessions, attendance records, leave requests, and timetable information.

---

## 1. Project Vision

Traditional attendance workflows in many colleges still depend on one or more of the following:

- manual roll-call,
- paper registers,
- spreadsheet post-processing,
- fragmented apps for different operations.

These approaches consume class time and make historical analytics difficult.  
Presenza addresses this by offering an integrated and mostly automated workflow:

1. Faculty starts a session for a class/subject/hour.
2. Session metadata is broadcast using BLE.
3. Student devices detect the session and respond.
4. Faculty observes detections in real time.
5. Attendance is finalized and stored in Firestore.

In addition, the platform includes:

- role-based dashboards,
- profile and curriculum views,
- leave and on-duty request workflows,
- attendance report export (PDF),
- class/faculty/student administration.

---

## 2. High-Level Architecture

The app follows a mobile-first, serverless pattern.

### 2.1 Client Layer (Flutter)

- Single Flutter codebase for Android/iOS.
- Material UI and custom assets.
- Modular screens by role:
  - `lib/Student/*`
  - `lib/Faculty/*`
  - `lib/Admin/*`
  - shared startup/auth in:
    - `lib/Startup/*`
    - `lib/Authentication/*`

### 2.2 Backend Layer (Firebase)

- **Firebase Core** for app integration.
- **Cloud Firestore** for domain data and real-time updates.
- **Firebase Storage** for stored artifacts when required.
- **Firebase Messaging** available for notification use cases.

### 2.3 Proximity Layer (BLE)

- Faculty side BLE broadcasting via `flutter_ble_peripheral`.
- Student side BLE scan/detection via BLE packages.
- Session payload carries class metadata and unique session ID.

---

## 3. Repository Structure

```text
camsvirtusa/
├── lib/
│   ├── main.dart
│   ├── Startup/
│   │   ├── routes.dart
│   │   ├── splashScreen.dart
│   │   └── roleSelection.dart
│   ├── Authentication/
│   │   ├── facultyLogin.dart
│   │   ├── studentLogin.dart
│   │   └── otpVerification.dart
│   ├── Admin/
│   │   ├── adminDashboard.dart
│   │   ├── facultyControl.dart
│   │   ├── studentControl.dart
│   │   ├── classControl.dart
│   │   ├── classesList.dart
│   │   ├── classStudents.dart
│   │   ├── departmentControl.dart
│   │   └── timeTable.dart
│   ├── Faculty/
│   │   ├── facultyDashboard.dart
│   │   ├── facultyTimetable.dart
│   │   ├── facultyProfile.dart
│   │   └── MarkAttendance.dart
│   └── Student/
│       ├── studentDashboard.dart
│       ├── studentAttendance.dart
│       ├── studentProfile.dart
│       ├── studentTimetable.dart
│       ├── studentOd.dart
│       ├── studentLeave.dart
│       └── StudentCurriculum.dart
├── assets/
├── android/
├── ios/
├── web/
├── windows/
├── linux/
├── macos/
├── test/
│   └── widget_test.dart
└── pubspec.yaml
```

---

## 4. Runtime Flow

### 4.1 App Startup

From `lib/main.dart`:

- Flutter bindings are initialized.
- Firebase is initialized (`Firebase.initializeApp()`).
- Orientation is locked to portrait.
- App boots with `MaterialApp`, custom routes, and themed typography.

### 4.2 Routing

Navigation is centralized in startup route definitions:

- splash/initial routes,
- role-selection entry,
- role-specific dashboards,
- transition between screens using named routes.

This gives consistent navigation behavior and simplifies role-based redirection.

### 4.3 Login Persistence

Both student and faculty/admin flows use `shared_preferences` for local session persistence:

- `isLoggedIn`
- `role`
- identity values (`studentId`, `facultyId`)

On launch, users can be auto-redirected directly to their dashboard when session state is valid.

---

## 5. Role-Based Functional Design

## 5.1 Student Role

Student-facing capabilities include:

1. **Authentication**  
   Login using student ID and password (and OTP flow where configured).

2. **Dashboard Access**  
   Quick navigation to attendance, timetable, profile, OD/Leave workflows, and curriculum views.

3. **Attendance Visibility**  
   Access attendance summary over semesters and subjects.

4. **Leave/OD Requests**  
   Submit leave or on-duty requests with details for faculty/admin review.

5. **Document Export**  
   Generate attendance reports as PDFs using `pdf` package integrations.

6. **Timetable and Curriculum**  
   Centralized academic information per student.

### 5.1.1 Student Login Data Path

`Authentication/studentLogin.dart` checks:

- Firestore path:
  - `colleges / students / all_students / {studentId}`
- password field match
- upon success:
  - local session persistence,
  - dashboard route transition.

### 5.1.2 Student Operational Benefits

- Less dependence on manual status updates.
- Better transparency in attendance records.
- Self-service for request workflows.
- Faster access to structured academic data.

---

## 5.2 Faculty Role

Faculty-facing capabilities include:

1. **Dual-path Login Handling**  
   Faculty login path can also route admin users when applicable.

2. **Class and Subject Context**  
   View assigned classes and timetable entries.

3. **Attendance Session Creation**  
   Select class/semester/subject/hour and run attendance process.

4. **BLE Session Broadcasting**  
   Faculty device advertises active session metadata.

5. **Live Detection Dashboard**  
   Real-time capture of student responses from Firestore streams.

6. **Finalize Attendance**  
   Save canonical attendance records once validation is complete.

### 5.2.1 Faculty Login Data Path

`Authentication/facultyLogin.dart` verifies:

1. Faculty collection:
   - `colleges / faculties / all_faculties / {id}`
2. If not present, checks admin collection:
   - `colleges / admins / all_admins / {id}`

Role is set in local session and user is redirected accordingly.

### 5.2.2 Attendance Workflow Details (`Faculty/MarkAttendance.dart`)

The attendance module includes:

- faculty profile/class loading,
- class selection UI,
- per-session BLE broadcast,
- live response monitoring subscription,
- attendance state handling and save operation.

Session payload includes fields similar to:

- `sessionId`
- `facultyId`
- `className`
- `subject`
- `hour`
- `date`

This enables deterministic matching of responses to active session context.

### 5.2.3 Why This Helps Faculty

- Reduced class-time overhead for attendance.
- Real-time confidence while session is active.
- Better historical traceability compared to paper systems.

---

## 5.3 Admin Role

Admin-facing capabilities center on institutional data governance:

1. **Department Management**
2. **Class Management**
3. **Faculty Management**
4. **Student Management**
5. **Class-Student Mapping**
6. **Timetable Management**

Admin modules ensure the rest of the system has valid, consistent master data.

---

## 6. Firestore Data Modeling (Conceptual)

The app uses collection hierarchies under a root grouping (`colleges`) with role-based sub-collections/documents.  
Observed patterns include:

- `colleges/faculties/all_faculties/{facultyId}`
- `colleges/students/all_students/{studentId}`
- `colleges/admins/all_admins/{adminId}`

Attendance and session-specific data are maintained in feature-specific collections from faculty/student modules.

### 6.1 Modeling Principles

For stability at scale, preserve:

1. **Stable IDs** for user documents.
2. **Single source of truth** for master entities.
3. **Denormalized read models** only when query performance requires it.
4. **Clear timestamps** for all transactional writes.
5. **Role-aware access control** via rules.

### 6.2 Suggested Attendance Record Fields

To keep records analytics-ready:

- studentId
- className
- department
- semester
- subject
- hour
- date
- status (Present/Absent/OD/Leave)
- facultyId
- sessionId
- createdAt / updatedAt

### 6.3 Suggested Leave/OD Fields

- studentId
- type (Leave / OnDuty)
- reason
- fromDate / toDate
- status (Pending / Approved / Rejected)
- reviewerId
- createdAt

---

## 7. BLE Attendance Design Notes

BLE is used as a short-range classroom signal, but reliable implementation needs careful control.

### 7.1 Session Identity

Each session should be unique.  
Current implementation includes timestamp + random component in `sessionId`.

### 7.2 Payload Size and Encoding

BLE advertisement payload is size-constrained.  
JSON payloads should stay compact; optional fields can be shortened or moved to server lookup to reduce size.

### 7.3 Reliability Controls

Recommended runtime safeguards:

- minimum broadcast duration window,
- duplicate response deduplication by `studentId + sessionId`,
- idempotent writes on server side,
- conflict handling for repeated detections.

### 7.4 Security Controls (Recommended)

For production hardening:

1. Add signed tokens in payload (HMAC with short expiry).
2. Validate signature before accepting session responses.
3. Reject stale/replayed session IDs.
4. Enforce Firestore write rules tied to authenticated identity.

---

## 8. Authentication and Authorization

Current role login checks are performed with Firestore lookups.  
For production use, the recommended evolution path is:

1. Move to **Firebase Authentication** for identity.
2. Store role claims in secure user profile/claims.
3. Keep Firestore as profile + domain data store.
4. Enforce role-based Firestore security rules.

### 8.1 Minimum Rule Strategy

- Student can read/write only own profile and request records.
- Faculty can update attendance records for assigned classes.
- Admin can perform master-data CRUD.
- Cross-role reads should be explicit and minimal.

---

## 9. UI/UX and Accessibility Principles

The project uses a clean, card-based, role-driven UI.  
To keep the app usable for diverse users:

1. Maintain clear contrast ratios.
2. Keep touch targets large enough.
3. Preserve consistent icon semantics.
4. Use predictable route transitions.
5. Keep error messaging actionable.

### 9.1 State Communication

All workflows should expose:

- loading state,
- empty state,
- success confirmation,
- recoverable error state.

---

## 10. Setup Guide

## 10.1 Prerequisites

- Flutter SDK (matching project Dart constraints)
- Android Studio / Xcode as needed
- Firebase project configured
- Device/emulator with Bluetooth support for BLE testing

## 10.2 Install

```bash
flutter pub get
```

## 10.3 Configure Firebase

Ensure platform-specific Firebase files are present:

- Android: `google-services.json`
- iOS: `GoogleService-Info.plist`

Configure Firestore and authentication settings in Firebase Console.

## 10.4 Run

```bash
flutter run
```

---

## 11. Build, Lint, and Test

Typical commands:

```bash
flutter analyze
flutter test
flutter build apk
```

> Note: In this execution environment, `flutter` binary may be unavailable. Run these commands locally/CI where Flutter is installed.

---

## 12. Quality Strategy

To keep the app stable while features evolve:

1. Add widget tests for role-specific navigation.
2. Add integration tests for login and attendance flows.
3. Add mock Firestore test suites for write/read validation.
4. Add regression tests for BLE session parsing and deduplication logic.

---

## 13. Performance Considerations

### 13.1 Firestore

- Avoid unnecessary deep listeners.
- Keep indexes aligned with query patterns.
- Paginate when listing large student/faculty sets.

### 13.2 UI

- Rebuild only affected widgets.
- Use async guards to prevent duplicate submissions.
- Cache frequently used static data.

### 13.3 BLE

- Balance advertisement interval for battery vs detection responsiveness.
- Cleanly stop broadcasting on exit/dispose.
- Handle device-level permission and Bluetooth off states clearly.

---

## 14. Security and Privacy Checklist

Before production rollout, ensure:

- [ ] Firestore rules are locked by role and ownership.
- [ ] Credentials are not stored in plaintext in user documents.
- [ ] Transport/session payloads include anti-replay checks.
- [ ] Sensitive identifiers are not over-exposed in logs.
- [ ] Permission prompts explain Bluetooth/location usage.
- [ ] Data retention policy is documented (attendance + requests).
- [ ] Audit trails exist for admin edits and attendance finalization.

---

## 15. Operational Workflows

## 15.1 Faculty Daily Workflow

1. Login.
2. Open assigned class.
3. Select semester/subject/hour.
4. Start BLE attendance session.
5. Review live detections.
6. Confirm and save attendance.

## 15.2 Student Daily Workflow

1. Login.
2. Keep Bluetooth active during class.
3. Session auto-detected.
4. Attendance reflected in records.
5. Raise leave/OD if needed.

## 15.3 Admin Academic Workflow

1. Maintain departments and classes.
2. Keep faculty and student records updated.
3. Manage class mappings and timetable.
4. Monitor request and attendance integrity trends.

---

## 16. Known Gaps and Recommended Enhancements

1. **Credential Hardening**  
   Replace plaintext password checks with secure auth workflow.

2. **Rule Enforcement**  
   Tighten Firestore security rules per role and scope.

3. **Attendance Analytics**  
   Add trend dashboards (subject-level deficits, risk alerts).

4. **Approval Pipelines**  
   Add structured SLAs/escalations for leave and OD requests.

5. **Notification Engine**  
   Use Firebase Messaging for reminders and approval updates.

6. **Institutional Multi-Tenant Support**  
   Generalize document hierarchy for multi-college deployments.

7. **Offline-First Patterns**  
   Improve deferred sync behavior for intermittent connectivity.

8. **Audit and Compliance Layer**  
   Preserve immutable audit events for critical actions.

---

## 17. Example Use Cases

### 17.1 Quick Attendance in Large Class

A faculty handling 60+ students can initiate one session and monitor detections in real time, reducing manual roll-call overhead.

### 17.2 Student Request Lifecycle

A student submits OD request with reason and dates; faculty/admin reviews and decides; outcome is visible in student dashboard.

### 17.3 Semester Review

Students export attendance report PDF for academic review and documentation.

---

## 18. Contributor Guide

### 18.1 Branching

- Use short-lived feature branches.
- Keep commits focused and atomic.

### 18.2 Code Style

- Follow Flutter style and lints.
- Prefer explicit, readable widget composition.
- Keep business logic testable and modular.

### 18.3 PR Readiness Checklist

- [ ] Feature works for target role.
- [ ] No route regression.
- [ ] Firestore paths validated.
- [ ] Error states handled.
- [ ] Lint/test run in CI-ready environment.
- [ ] Documentation updated.

---

## 19. Troubleshooting

### Issue: Login succeeds but route is wrong

- Verify `role` stored in shared preferences.
- Check route mapping and navigation arguments.

### Issue: BLE session starts but no student detection

- Confirm Bluetooth permission and device support.
- Verify payload/session fields match expected student scanner logic.
- Check Firestore write permissions and path consistency.

### Issue: Attendance not saved

- Validate selected subject/hour/date context.
- Confirm faculty assignment and class mapping.
- Inspect Firestore write errors and indexes.

---

## 20. Conclusion

Presenza (camsvirtusa) is a practical mobile attendance ecosystem combining:

- role-based operations,
- BLE-assisted classroom signaling,
- real-time backend synchronization,
- and college administration workflows in a single app.

With additional production hardening in authentication, security rules, and analytics, the project can evolve into a robust institutional platform suitable for daily academic operations at scale.
