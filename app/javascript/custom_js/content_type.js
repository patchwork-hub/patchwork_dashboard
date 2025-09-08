document.addEventListener("DOMContentLoaded", () => {
  const elements = {
    contributorOr: document.getElementById("contributor_or"),
    contributorAnd: document.getElementById("contributor_and"),
    communityId: document.getElementById("community_id"),
  };

  const createOrUpdateContentType = (conditionType) => {
    const communityId = elements.communityId.value;
    const url = `/content_types`;
    const method = "POST";

    fetch(url, {
      method: method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").getAttribute("content"),
      },
      body: JSON.stringify({
        content_type: {
          patchwork_community_id: communityId,
          custom_condition: conditionType,
        }
      })
    }).then(response => {
      if (response.ok) {
      } else {
        console.error("Error creating or updating content type");
      }
    });
  };

  const toggleCheckboxes = (primary, secondary) => {
    if (primary.checked) {
      secondary.checked = false;
      createOrUpdateContentType(primary.id === "contributor_or" ? "or_condition" : "and_condition");
    }
  };

  if (elements.contributorOr) {
    elements.contributorOr.addEventListener("change", () => {
      toggleCheckboxes(elements.contributorOr, elements.contributorAnd);
    });
  }

  if (elements.contributorAnd) {
    elements.contributorAnd.addEventListener("change", () => {
      toggleCheckboxes(elements.contributorAnd, elements.contributorOr);
    });
  }
});
