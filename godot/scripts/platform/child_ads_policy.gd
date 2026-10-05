extends RefCounted

## Unicorn Arcade has a child-only audience. Configuration cannot widen its inventory.
static func permits_ads(config: Dictionary) -> bool:
	var child_treatment: Variant = config.get("child_directed", true)
	var rating: Variant = config.get("max_ad_content_rating", "G")
	return typeof(child_treatment) == TYPE_BOOL and child_treatment == true \
		and typeof(rating) == TYPE_STRING and rating == "G"


static func request_configuration() -> RequestConfiguration:
	var request := RequestConfiguration.new()
	request.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE
	# Google specifies that TFCD and TFUA should not both be true. TFCD owns this child-only app.
	request.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.UNSPECIFIED
	request.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	return request
