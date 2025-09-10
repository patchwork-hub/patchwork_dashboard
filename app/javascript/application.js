import "bootstrap";
import "admin-lte";
import "@nathanvda/cocoon";

import "lib/datatable";
import "custom_js/api_util";
import "custom_js/modal_handler";
import "custom_js/keyword_groups";
import "custom_js/header";
import "custom_js/search_contributor";
import 'custom_js/search_mute_contributor';
import 'custom_js/post_hashtag';
import 'custom_js/community_preview';
import 'custom_js/content_type'
import 'custom_js/admin'

import { far } from "@fortawesome/free-regular-svg-icons";
import { fas } from "@fortawesome/free-solid-svg-icons";
import { fab } from "@fortawesome/free-brands-svg-icons";
import { library } from "@fortawesome/fontawesome-svg-core";
import "@fortawesome/fontawesome-free";
library.add(far, fas, fab);

import Rails from "@rails/ujs";
Rails.start();

localStorage.setItem("selected", null);
localStorage.setItem("unselected", null);

import ClassicEditor from "@ckeditor/ckeditor5-build-classic";

$(document).ready(function () {
  document.querySelectorAll(".ckeditor").forEach((element) => {
    ClassicEditor.create(element).catch((error) => {
      console.error(error);
    });
  });

  const admin_note = document.getElementById("master_admin_note");
  if (admin_note) {
    ClassicEditor.create(admin_note, {
      toolbar: ["bold", "italic", "link"],
    }).catch((error) => {
      console.error(error);
    });
  }

  function initializeSelect2() {
    $('.select2-icon').select2({
      templateResult: formatIcon,
      templateSelection: formatIcon,
      width: '100%',
      escapeMarkup: function(m) { return m; }
    });
  }

  $(document).on('ready cocoon:after-insert', function() {
    initializeSelect2();
  });

  function formatIcon(icon) {
    if (!icon.id) return icon.text;
    const iconPath = $(icon.element).data('icon');
    return $(
      `<span><img src="${iconPath}" class="select2-icon-image mr-2" />${icon.text}</span>`
    );
  }

  $(".select2").select2({
    dropdownParent: $("#keyFilterModal"),
    tags: true,
    placeholder: "Select an option",
    allowClear: true,
    theme: "bootstrap",
  });

  const keywordFilterForm = document.querySelector("#keyFilterModal form");

  if (keywordFilterForm) {
    keywordFilterForm.addEventListener("submit", function (event) {
      event.preventDefault();
      const formData = new FormData(keywordFilterForm);
      const url = keywordFilterForm.action;
      const submitButton = document.querySelector(".submit-btn");

      clearPreviousErrors();

      if (!validateKeywords()) {
        displayErrorMessage("Keyword cannot be blank.");
        enableSubmitButton(submitButton);
        return;
      }

      fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document
            .querySelector('meta[name="csrf-token"]')
            .getAttribute("content"),
        },
        body: formData,
      })
        .then((response) => response.json())
        .then((data) => {
          if (data.success) {
            location.reload();
          } else {
            enableSubmitButton(submitButton);
            handleKeywordFilterGroupErrors(data.error);
          }
        })
        .catch((error) => {
          console.error("Error submitting form:", error);
          displayErrorMessage(
            "An unexpected error occurred. Please try again."
          );
          enableSubmitButton(submitButton);
        });
    });
  }

  function clearPreviousErrors() {
    document.querySelectorAll(".error-message").forEach((el) => el.remove());
    document
      .querySelectorAll(".form-control")
      .forEach((el) => el.classList.remove("is-invalid"));
  }

  function validateKeywords() {
    let isValid = true;
    document
      .querySelectorAll(
        'input[name^="keyword_filter_group[keyword_filters_attributes]"][name$="[keyword]"]'
      )
      .forEach((input) => {
        if (!input.value.trim()) {
          input.classList.add("is-invalid");
          isValid = false;
        }
      });
    return isValid;
  }

  function displayErrorMessage(message) {
    const errorMessage = document.createElement("small");
    errorMessage.className = "error-message text-danger";
    errorMessage.textContent = message;
    document
      .querySelectorAll(
        'input[name^="keyword_filter_group[keyword_filters_attributes]"][name$="[keyword]"]'
      )
      .forEach((input) => {
        if (input.classList.contains("is-invalid")) {
          input.after(errorMessage.cloneNode(true));
        }
      });
  }

  function enableSubmitButton(button) {
    if (button) {
      button.disabled = false;
      button.removeAttribute("data-disable-with");
    }
  }

  function handleKeywordFilterGroupErrors(errorMessage) {
    const errors = errorMessage.split(", ");
    errors.forEach((error) => {
      const errorElement = document.createElement("small");
      errorElement.className = "error-message text-danger";
      errorElement.textContent = error;

      if (error.includes("Name")) {
        const nameInput = document.querySelector(
          'input[name="keyword_filter_group[name]"]'
        );
        if (nameInput) {
          nameInput.classList.add("is-invalid");
          nameInput.after(errorElement);
        }
      } else if (error.includes("Keyword")) {
        document
          .querySelectorAll(
            'input[name^="keyword_filter_group[keyword_filters_attributes]"][name$="[keyword]"]'
          )
          .forEach((input) => {
            if (input) {
              input.classList.add("is-invalid");
              input.after(errorElement);
            }
          });
      }
    });
  }

  const nestedAttributeContainer = document.querySelector(".nested-fields");

  if (
    nestedAttributeContainer &&
    nestedAttributeContainer.children.length === 0
  ) {
    const addNewLink = nestedAttributeContainer.querySelector(".add_fields");
    if (addNewLink) {
      addNewLink.click();
    }
  }

  const collapseToggles = document.querySelectorAll(".collapse-toggle");

  collapseToggles.forEach(function (toggle) {
    toggle.addEventListener("click", function () {
      const arrowDown = toggle.querySelector(".icon-arrow-down");
      const arrowUp = toggle.querySelector(".icon-arrow-up");

      if (toggle.getAttribute("aria-expanded") === "true") {
        arrowDown.style.display = "inline-block";
        arrowUp.style.display = "none";
      } else {
        arrowDown.style.display = "none";
        arrowUp.style.display = "inline-block";
      }
    });
  });

  const saveChangeButtons = document.querySelectorAll('.save-change');

  saveChangeButtons.forEach(button => {
    button.addEventListener('click', () => {
      window.location.reload();
    });
  });

  // Function to copy text to clipboard
  function copyToClipboard(text) {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);
  }

  // Attach the function to the window object to make it globally accessible
  window.copyToClipboard = copyToClipboard;
});


const togglePassword = (e) => {
  let input = e.closest('div').querySelector("input[type='password'], input[type='text']");
  if (input) {
    if (input.type === "password") {
      e.setAttribute("class", "svg-inline--fa fa-eye red");
      input.type = "text";
    } else {
      e.setAttribute("class", "svg-inline--fa fa-eye-slash red");
      input.type = "password";
    }
  } else {
    console.error("No input element found!");
  }
};

window.togglePassword = togglePassword;

document.addEventListener('DOMContentLoaded', function () {
  // Reusable function to handle code generation
  function handleCodeGeneration(buttonId, channelType) {
    const button = document.getElementById(buttonId);
    if (button) {
      button.addEventListener('click', function () {
        $.ajax({
          url: `/api/v1/wait_list?channel_type=${channelType}`,
          type: 'POST',
          dataType: 'json',
          success: function (response) {
            if (response.data) {
              const alertBox = document.createElement('div');
              alertBox.className = 'w-100 rounded text-center';
              const alertHeading = document.createElement('span');
              alertHeading.className = 'd-block p-2 bg-secondary bg-gradient text-white w-100 rounded';
              alertHeading.textContent = "Generated code: " + response.data.invitation_code;
              alertBox.appendChild(alertHeading);
              const cardTools = document.querySelector('.preview_code');
              if (cardTools) {
                cardTools.appendChild(alertBox); // Append the alert box to the .card-tools element
              }
              setTimeout(() => {
                location.reload();
              }, 5000); // Reload the page after 3 seconds
            }
          },
          error: function (xhr) {
            alert('Error: ' + xhr.responseText);
          }
        });



      });
    }
  }

  // Attach event listeners for the buttons
  handleCodeGeneration('create-channel-code-btn', 'channel');
  handleCodeGeneration('create-hub-code-btn', 'hub');

  document.querySelectorAll('.deprecated-checkbox').forEach((checkbox) => {
    checkbox.addEventListener('change', (event) => {
      const checkbox = event.target;
      const id = checkbox.dataset.id;
      const osType = checkbox.dataset.os_type;
      const deprecated = checkbox.checked;

      fetch(`/history/${id}/deprecate`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ deprecated, os_type: osType }),
      })
        .then((response) => {
          if (!response.ok) {
            throw new Error('Failed to update deprecated status');
          }
          return response.json();
        })
        .catch((error) => {
          console.error('Error:', error);
          checkbox.checked = !deprecated; // Revert checkbox state on error
        });
    });
  });
});
