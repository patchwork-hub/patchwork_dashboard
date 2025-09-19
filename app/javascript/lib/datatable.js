import $ from 'jquery';
import DataTable from 'datatables.net-bs4';
import 'datatables.net-select-bs4';
import { sendPatchRequest } from 'custom_js/api_util';

const COLUMNS = {
  keyword_filter_group_list: [
    { data: 'name' },
    { data: 'server_setting' },
    { data: 'is_active' },
    {
      data: 'keyword_filters',
      render: function(data, type, row) {
        if (data && Array.isArray(data)) {
          return '<ul>' + data.map(function(filter) {
            return `<li>${filter.keyword}</li>`;
          }).join('') + '</ul>';
        } else {
          return '';
        }
      }
    }
  ]
};

const COLUMN_DEFS = {};

jQuery(function() {
  // Show preview modal if show_preview param is present in URL
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('show_preview') === 'true') {
    $('#previewCommunityModal').modal('show');
  }

  $('#datatable').css('width', '100%');

  let url = $('#datatable').data('url');
  let type = $('#datatable').data('type');
  let selectable = $('#datatable').data('selectable');
  let isCustom = $('#datatable').data('is-custom');

  if (isCustom) {
    COLUMNS.keyword_filter_group_list.push({
      data: 'keyword_filters',
      render: function(data, type, row) {
        if (data && Array.isArray(data)) {
          return '<ul>' + data.map(function(filter) {
            const editUrl = filter.edit_url;
            const deleteUrl = filter.delete_url;
            const editClass = filter.is_custom_group ? '' : 'disabled';
            const deleteClass = filter.is_custom_group ? '' : 'disabled';
            const actions = filter.is_custom_group ? `<li>
                      <a href="${editUrl}" class="edit-icon ${editClass}" title="Edit"><i class="fas fa-edit"></i></a>
                      <a href="${deleteUrl}" class="delete-icon ${deleteClass}" title="Delete" data-confirm="Are you sure?" data-method="delete"><i class="fas fa-trash"></i></a>
                    </li>` : '';
            return actions;
          }).join('') + '</ul>';
        } else {
          return '';
        }
      }
    });
  }

  let options = {
    destroy: false,
    paging: false,
    searching: false,
    serverSide: true,
    processing: true,
    lengthMenu: false,
    info: false,
    ajax: {
      type: "GET",
      url: url,
      dataType: "json",
      data: (d) => {
        let selected = localStorage.getItem('selected');
        if (selected == 'all') {
          d.selected = selected;
        } else {
          d.selected = JSON.parse(selected) || [];
        }

        let unselected = localStorage.getItem('unselected');
        if (unselected) {
          d.unselected = JSON.parse(unselected) || [];
        }
      },
    },
    columns: COLUMNS[type],
    columnDefs: COLUMN_DEFS[type],
  };

  if (selectable == 'multi') {
    options['select'] = {
      style: 'multi',
      selector: 'td:first-child'
    };
  }

  var table = $('#datatable').DataTable(options);

  // Handling multiple selection
  var table_without_option = $('#datatable').DataTable();

  table_without_option.on('draw', function() {
    $('tr').each(function() {
      var row = $(this);
      var checkbox = row.find('.checkbox');

      if (checkbox.is(':checked')) {
        row.addClass('selected');
      } else {
        row.removeClass('selected');
      }
    });
  });

  // Handling modal close event
  $('#keyFilterModal').on('hidden.bs.modal', function () {
    var form = $(this).find('form')[0];
    if (form) {
      form.reset();
    }

    $(this).find('.error-message').remove();
    $(this).find('.is-invalid').removeClass('is-invalid');

    handleNestedFields($(this).find('.nested-fields'));
    $('#keyword_filter_group_name').val(null).trigger('change');
  });

  function handleNestedFields(nestedFieldsContainer) {
    var nestedFields = nestedFieldsContainer.parent().children('.nested-fields');

    if (nestedFields.length > 1) {
      nestedFields.slice(1).remove();
    }

    nestedFields.find('input[type="text"]').val('');
  }

  // Add this function to handle modal button visibility
  function toggleModalButtons(inputValue) {
    const closeButton = document.querySelector('#maxCharsModal .btn-secondary');
    const crossButton = document.querySelector('#maxCharsModal .close');
    
    if (inputValue && inputValue.trim() !== '') {
      // Show buttons when input has value
      if (closeButton) closeButton.style.display = 'block';
      if (crossButton) crossButton.style.display = 'block';
    } else {
      // Hide buttons when input is empty
      if (closeButton) closeButton.style.display = 'none';
      if (crossButton) crossButton.style.display = 'none';
    }
  }

  window.handleEditClick = function(element) {
    var maxCharsValue = element.getAttribute('data-optional-value');
    var maxCharsInput = document.getElementById('max_chars_value');
    maxCharsInput.value = maxCharsValue || '';

    // Toggle buttons based on initial value
    toggleModalButtons(maxCharsValue);
  };

  function updateSetting(checkbox) {
    const settingId = checkbox.getAttribute('data-setting-id');
    const isChecked = checkbox.checked;
    const data = { server_setting: { value: isChecked } };

    sendPatchRequest(`/server_settings/${settingId}`, data);
  }

  // Update the existing modal show event handler
  $('#maxCharsModal').on('show.bs.modal', function() {
    const maxCharsInput = document.getElementById('max_chars_value');
    
    // Initially hide buttons if no value
    toggleModalButtons(maxCharsInput ? maxCharsInput.value : '');
    
    // Add event listener for input changes
    if (maxCharsInput) {
      maxCharsInput.addEventListener('input', function() {
        toggleModalButtons(this.value);
      });
      
      // Also listen for keyup to catch all changes
      maxCharsInput.addEventListener('keyup', function() {
        toggleModalButtons(this.value);
      });
    }
  });

  // Reset button visibility when modal is hidden
  $('#maxCharsModal').on('hidden.bs.modal', function() {
    const closeButton = document.querySelector('#maxCharsModal .btn-secondary');
    const crossButton = document.querySelector('#maxCharsModal .close');
    
    // Reset to visible state for next time
    if (closeButton) closeButton.style.display = 'block';
    if (crossButton) crossButton.style.display = 'block';
  });

  function showModalIfNeeded(checkbox) {
    const settingName = checkbox.getAttribute('data-setting-name').toLowerCase();

    if (settingName === 'long posts and markdown' && checkbox.checked) {
      const optionalValue = checkbox.getAttribute('data-optional-value');
      const maxCharsInput = document.getElementById('max_chars_value');
      maxCharsInput.value = optionalValue || '';

      $('#maxCharsModal').modal('show');
    }
  }

  const settingSwitches = document.querySelectorAll('.setting-input');
  settingSwitches.forEach(function(switchElement) {
    switchElement.addEventListener('change', function(event) {
      const checkbox = event.target;
      updateSetting(checkbox);
      showModalIfNeeded(checkbox);
    });
  });

  const saveMaxCharsButton = document.getElementById('saveMaxChars');
  if (saveMaxCharsButton) {
    saveMaxCharsButton.addEventListener('click', function() {
      const maxCharsInput = document.getElementById('max_chars_value');
      const newValue = maxCharsInput ? maxCharsInput.value || '500' : '';

      const settingElement = Array.from(document.querySelectorAll('.setting-input'))
        .find(el => el.getAttribute('data-setting-name').toLowerCase() === 'long posts and markdown');

      if (settingElement) {
        const settingId = settingElement.getAttribute('data-setting-id');
        const data = { server_setting: { optional_value: newValue } };
        sendPatchRequest(`/server_settings/${settingId}`, data)
          .then(() => {
            location.reload();
          });
      }
    });
  }

  $('#CommunityFilterModal').on('show.bs.modal', function(event) {
    var button = $(event.relatedTarget);
    var keywordId = button.data('id');
    var keyword = button.data('keyword');
    var isFilterHashtag = button.data('isFilterHashtag');

    var modal = $(this);
    var form = modal.find('form');
    var modalTitle = modal.find('.modal-title');
    var keywordInput = $('#keyword-input');
    var isFilterHashtagInput = $('#is_filter_hashtag-input');

    if (keywordId) {
      // Editing keyword filter
      modalTitle.text('Edit keyword filtering');
      form.find('input[name="_method"]').val('patch');
      form.attr('action', `/community_filter_keywords/${keywordId}`);
      keywordInput.val(keyword);
      if (isFilterHashtagInput) {
        isFilterHashtagInput.prop('checked', isFilterHashtag == true);
      }
    } else {
      // Adding new keyword filter
      modalTitle.text('Add keyword filtering');
      form.attr('action', '/community_filter_keywords');
      form.find('input[name="_method"]').val('post');
      keywordInput.val('');
      if (isFilterHashtagInput) {
        isFilterHashtagInput.prop('checked', false);
      }
    }
    var csrfToken = $('meta[name="csrf-token"]').attr('content');
    form.append(`<input type="hidden" name="authenticity_token" value="${csrfToken}">`);
  });

  $('#editHashtagModal').on('show.bs.modal', function (event) {
    var button = $(event.relatedTarget);
    var hashtagId = button.data('id');
    var hashtag = button.data('hashtag');

    var modal = $(this);
    modal.find('#edit_hashtag_id').val(hashtagId);
    modal.find('#edit_hashtag_input').val('#' + hashtag);

    var form = modal.find('#edit_hashtag_form');
    var communityId = $('#edit_community_id').val();
    var actionUrl = '/channels/' + communityId + '/community_hashtags/' + hashtagId;
    form.attr('action', actionUrl);
  });

  const saveAndPreviewBtn = document.getElementById("save-and-preview-btn");
  const form = document.getElementById("additionalForm");

  if (saveAndPreviewBtn) {
    saveAndPreviewBtn.addEventListener("click", function(event) {
      event.preventDefault();
      form.submit();
    });
  }

  const uploadInputs = document.querySelectorAll(".upload-input");

  if (uploadInputs) {
    uploadInputs.forEach((input) => {
      const previewId = input.getAttribute("data-preview-id");
      const aspectRatio = parseFloat(input.getAttribute("data-aspect-ratio"));
      setupFileUpload(input.id, previewId, aspectRatio);
    });
  }

  function setupFileUpload(inputId, previewId, aspectRatio) {
    const input = document.getElementById(inputId);
    const previewImg = document.getElementById(previewId);

    if (!input || !previewImg) {
      console.error(`Input or Preview element not found.`);
      return;
    }

    input.addEventListener("change", function () {
      const file = this.files[0];
      if (!file) {
        return;
      }

      const reader = new FileReader();
      reader.onload = function (e) {
        const image = new Image();
        image.onload = function () {
          const modal = document.createElement("div");
          modal.style.cssText = `
            position: fixed;
            display: flex;
            flex-direction: column;
            justify-content: flex-end;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0, 0, 0, 0.7);
            z-index: 1000;
            display: flex;
            justify-content: center;
            align-items: center;
          `;

          const cropperContainer = document.createElement("div");
          cropperContainer.style.cssText = `
            background-color: #fff;
            border-radius: 6px 6px 0 0;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
            overflow: hidden;
            max-width: 60vw;
            max-height: 60vh;
          `;

          const cropperImage = document.createElement("img");
          cropperImage.src = image.src;
          cropperImage.style.cssText = `
            display: block;
            max-width: 100%;
            max-height: 100%;
            width: auto;
            height: auto;
          `;

          const buttonContainer = document.createElement("div");
          buttonContainer.style.cssText = `
            display: flex;
            justify-content: flex-end;
            gap: 10px;
            padding: 10px;
            background-color: #fff;
            border-radius: 0 0 6px 6px;
            border-top: 1px solid #ddd;
            max-width: 60vw;
            margin: 0 auto;
            width: auto;
          `;

          const closeButton = document.createElement("button");
          closeButton.textContent = "Close";
          applyButtonStyle(closeButton, "#6c757d");

          const cropButton = document.createElement("button");
          cropButton.textContent = "Crop";
          applyButtonStyle(cropButton, "#DC3545");

          buttonContainer.appendChild(closeButton);
          buttonContainer.appendChild(cropButton);

          cropperContainer.appendChild(cropperImage);
          modal.appendChild(cropperContainer);
          modal.appendChild(buttonContainer);
          document.body.appendChild(modal);

          const cropper = new Cropper(cropperImage, {
            aspectRatio: aspectRatio,
            viewMode: 1,
            dragMode: 'move',
            autoCropArea: 1,
            responsive: true,
            guides: true,
            background: false,
            zoomable: true,
            cropBoxMovable: true,
            cropBoxResizable: true,
            restore: false,
            checkCrossOrigin: false,
            checkOrientation: false,
            ready: function() {
              buttonContainer.style.width = cropperContainer.offsetWidth + "px";
            }
          });

          cropButton.addEventListener("click", () => {
            const canvas = cropper.getCroppedCanvas();
            canvas.toBlob((blob) => {
              if (previewImg.src.startsWith("blob:")) {
                URL.revokeObjectURL(previewImg.src);
              }
              const url = URL.createObjectURL(blob);
              previewImg.src = url;
              previewImg.style.display = "block";

              const dataTransfer = new DataTransfer();
              dataTransfer.items.add(new File([blob], "cropped-image.jpg", { type: "image/jpeg" }));
              input.files = dataTransfer.files;
              document.body.removeChild(modal);
            }, "image/jpeg");
          });

          closeButton.addEventListener("click", () => {
            document.body.removeChild(modal);
          });
        };

        image.onerror = function () {
          console.error("Error loading the image.");
          alert("Failed to load the image. Please try again.");
          if (modal.parentNode) {
            document.body.removeChild(modal);
          }
        };
        image.src = e.target.result;
      };

      reader.onerror = function () {
        console.error("Error reading the file.");
        alert("Failed to read the file. Please try again.");
      };

      reader.readAsDataURL(file);
    });
  }

  function applyButtonStyle(button, backgroundColor) {
    button.style.cssText = `
      padding: 10px 20px;
      background-color: ${backgroundColor};
      color: #fff;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-size: 1rem;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
      flex: 1;
    `;
  }
});
