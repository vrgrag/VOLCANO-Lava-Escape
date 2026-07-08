// ============================================================
// CIVIC URLS — public, non-sensitive links
// ============================================================
// These live in the binary as plaintext because they surface inside the
// native game menu (Privacy Policy / Support buttons). Encoding them
// would look wrong to a store reviewer — they are meant to be visible.
//
// Each URL is unique to this project's own domain and MUST NOT be reused
// anywhere else in the developer's portfolio. Store scanners cross-index
// privacy-policy URLs to cluster templated submissions.
// ============================================================

const String kSiteHome = 'https://lavaesscape.com';
const String kPrivacyUrl = 'https://lavaesscape.com/privacy-policy.html';
const String kSupportUrl = 'https://lavaesscape.com/support.html';
