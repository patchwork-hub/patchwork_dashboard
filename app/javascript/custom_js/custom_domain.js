$(document).ready(function () {
  const CommunitySetup = (function () {
    // Cache frequently used jQuery elements.
    const $container = $(".container-fluid");
    const $domainSwitch = $("#domain_switch");
    const $subdomainSection = $("#subdomain_section");
    const $customDomainSection = $("#custom_domain_section");
    const $customDomainInput = $("#custom_domain_input");
    const $continueButton = $("#continue_button");
    const $form = $("form");

    // State to keep track of current mode and verification.
    let state = {
      isChannelFeed: $container.data("is-channel-feed"),
      currentDomain: "",
      domainVerified: false,
      isSubdomainMode: !$domainSwitch.is(":checked"),
    };

    // Cache additional DOM elements.
    const elements = {
      refreshBtn: $("#refresh_domain_btn"),
      addDomainBtn: $("#add_domain_btn"),
      editDomainBtn: $("#edit_domain_btn"),
      dnsTable: $("#dns_records_table"),
      domainStatus: $("#domain_status"),
      addDomainStatus: $("#add_domain_status"),
    };

    // Initialize the module.
    function init() {
      if (!state.isChannelFeed) {
        bindEvents();
        handleInitialState();
      }
      updateContinueButton();
    }

    // Bind event handlers.
    function bindEvents() {
      $domainSwitch.on("change", handleDomainSwitch);
      $subdomainSection.find("input").on("keyup change", updateContinueButton);
      $customDomainInput.on("keyup change", updateContinueButton);
      $form.on("submit", handleFormSubmit);
      elements.refreshBtn.on("click", handleDomainRefresh);
      elements.addDomainBtn.on("click", handleAddDomain);
      elements.editDomainBtn.on("click", handleEditDomain);
    }

    // Handle the switch between custom domain and subdomain modes.
    function handleDomainSwitch() {
      const isCustomDomain = $(this).is(":checked");
      state.isSubdomainMode = !isCustomDomain;
      toggleSections(isCustomDomain);
      updateContinueButton();

      if (isCustomDomain) {
        const customVal = $customDomainInput.val().trim();
        if (customVal !== "") {
          state.currentDomain = customVal;
          $("#domain_text").text(customVal);
          toggleDomainUI(true);
          verifyDomain(customVal);
        } else {
          state.currentDomain = "";
          toggleDomainUI(false);
        }
      } else {
        toggleDomainUI(false);
      }
      updateContinueButton();
    }

    // Disable inputs in the hidden section before form submission.
    function handleFormSubmit() {
      const slugInput = state.isSubdomainMode
        ? $subdomainSection.find('input[name="form_community[slug]"]')
        : $customDomainSection.find('input[name="form_community[slug]"]');

      $subdomainSection.find("input").prop("disabled", !state.isSubdomainMode);
      $customDomainSection
        .find("input")
        .prop("disabled", state.isSubdomainMode);
    }

    // Re-trigger domain verification.
    function handleDomainRefresh() {
      if (state.currentDomain) {
        verifyDomain(state.currentDomain);
      }
    }

    // "Add Domain" handler: user explicitly enters a custom domain.
    function handleAddDomain() {
      const domain = $customDomainInput.val().trim();
      if (!domain)
        return showStatus(
          "Please enter a domain",
          false,
          elements.addDomainStatus
        );

      state.currentDomain = domain;
      $("#domain_text").text(domain);
      toggleDomainUI(true);
      verifyDomain(domain);
    }

    // "Edit Domain" handler: show the input group for editing.
    function handleEditDomain() {
      toggleDomainUI(false);
      $customDomainSection.show();
      $customDomainInput.val(state.currentDomain).trigger("focus");
    }

    // Verify the domain via AJAX.
    async function verifyDomain(domain) {
      try {
        setLoadingState(true);
        const ipAddress = $('input[name="form_community[ip_address]"]').val();
        const response = await $.ajax({
          url: "/domain/verify",
          data: { domain: domain, ipAddress: ipAddress },
        });
        state.domainVerified = response.verified;
        showStatus(response.message, response.verified, elements.domainStatus);
      } catch (error) {
        state.domainVerified = false;
        showStatus(
          "Verification failed. Please try again.",
          false,
          elements.domainStatus
        );
      } finally {
        setLoadingState(false);
        updateContinueButton();
      }
    }

    // Toggle between subdomain and custom domain sections.
    function toggleSections(isCustomDomain) {
      $subdomainSection.toggle(!isCustomDomain);
      $customDomainSection.toggle(isCustomDomain);
      elements.dnsTable.hide();
    }

    // Toggle showing the DNS table vs. the custom domain input group.
    function toggleDomainUI(showDnsTable) {
      $("#custom_domain_group").toggle(!showDnsTable);
      elements.dnsTable.toggle(showDnsTable);
      elements.domainStatus.empty();
    }

    // Update the refresh button UI during AJAX.
    function setLoadingState(isLoading) {
      elements.refreshBtn
        .prop("disabled", isLoading)
        .html(
          isLoading
            ? '<i class="fas fa-spinner fa-spin"></i>'
            : '<i class="fas fa-sync-alt"></i>'
        );
    }

    // Display status messages.
    function showStatus(message, isSuccess, container) {
      const statusClass = isSuccess ? "text-success" : "text-danger";
      const icon = isSuccess ? "fa-check-circle" : "fa-times-circle";
      container.html(`
        <div class="d-flex align-items-center ${statusClass}">
          <i class="fas ${icon} me-2"></i>
          <span class="small ml-2">${message}</span>
        </div>
      `);
    }

    // Update the Continue button based on current state.
    function updateContinueButton() {
      if (state.isChannelFeed) {
        $continueButton.prop("disabled", false);
        return;
      }

      const subdomainVal = $subdomainSection.find("input").val();
      const customDomainVal = $customDomainInput && $customDomainInput.length ? $customDomainInput.val() : "";

      const isDisabled = state.isSubdomainMode
        ? !subdomainVal || subdomainVal.trim() === ""
        : !(state.domainVerified && customDomainVal && customDomainVal.trim());
      $continueButton.prop("disabled", isDisabled);
    }

    // Set the initial UI state when the page loads.
    function handleInitialState() {
      if ($domainSwitch.length && $domainSwitch.is(":checked")) {
        const domain = $customDomainInput.val().trim();
        if (domain !== "") {
          state.currentDomain = domain;
          $("#domain_text").text(domain);
          toggleDomainUI(true);
          $subdomainSection.hide();
          verifyDomain(domain);
          return;
        }
      }
      $domainSwitch.trigger("change");
    }

    return { init };
  })();

  const $channelType = $("#channel_type").val();

  if ($channelType !== "channel_feed" && $channelType !== "newsmast") {
    CommunitySetup.init();
  }
});
