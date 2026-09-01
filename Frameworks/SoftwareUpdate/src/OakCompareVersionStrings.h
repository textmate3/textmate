// Compares dotted version strings component by component, numerically where both components are
// numeric, so 2.0.10 orders after 2.0.9. Used to decide whether one bundle is newer than another.
NSComparisonResult OakCompareVersionStrings (NSString* lhsString, NSString* rhsString);
