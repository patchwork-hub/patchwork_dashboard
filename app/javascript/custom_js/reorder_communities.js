document.addEventListener('DOMContentLoaded', function () {
  var list = document.getElementById('sortable-community-list');
  if (!list) return;

  // Load SortableJS from CDN
  var script = document.createElement('script');
  script.src = 'https://cdn.jsdelivr.net/npm/sortablejs@1.15.0/Sortable.min.js';
  script.onload = function () {
    new Sortable(list, {
      animation: 150,
      handle: '.drag-handle',
      ghostClass: 'sortable-ghost',
      onEnd: function () {
        updatePositionInputs();
      }
    });
  };
  document.head.appendChild(script);

  // After drag-and-drop, update all position inputs sequentially
  function updatePositionInputs() {
    var items = list.querySelectorAll('.list-group-item');
    items.forEach(function (item, index) {
      var input = item.querySelector('.position-input');
      if (input) input.value = index + 1;
    });
  }

  // When a position input is changed, re-sort the list by input values
  list.addEventListener('change', function (e) {
    if (!e.target.classList.contains('position-input')) return;

    var items = Array.from(list.querySelectorAll('.list-group-item'));

    items.sort(function (a, b) {
      var posA = parseInt(a.querySelector('.position-input').value) || 0;
      var posB = parseInt(b.querySelector('.position-input').value) || 0;
      return posA - posB;
    });

    items.forEach(function (item) {
      list.appendChild(item);
    });

    validateUniquePositions();
  });

  // Validate that all position values are unique
  function validateUniquePositions() {
    var inputs = list.querySelectorAll('.position-input');
    var values = {};
    var hasDuplicates = false;

    // Reset all styles
    inputs.forEach(function (input) {
      input.style.borderColor = '';
      input.style.backgroundColor = '';
    });

    // Find duplicates
    inputs.forEach(function (input) {
      var val = input.value;
      if (values[val]) {
        values[val].push(input);
        hasDuplicates = true;
      } else {
        values[val] = [input];
      }
    });

    // Highlight duplicates
    Object.keys(values).forEach(function (key) {
      if (values[key].length > 1) {
        values[key].forEach(function (input) {
          input.style.borderColor = '#dc3545';
          input.style.backgroundColor = '#fff5f5';
        });
      }
    });

    var statusEl = document.getElementById('reorder-status');
    var saveBtn = document.getElementById('save-order-btn');
    if (hasDuplicates) {
      statusEl.innerHTML = '<span class="text-danger"><i class="fa-solid fa-triangle-exclamation"></i> Duplicate positions found</span>';
      saveBtn.disabled = true;
    } else {
      statusEl.innerHTML = '';
      saveBtn.disabled = false;
    }

    return !hasDuplicates;
  }

  // Save button
  var saveBtn = document.getElementById('save-order-btn');
  if (saveBtn) {
    saveBtn.addEventListener('click', function () {
      var items = list.querySelectorAll('.list-group-item');
      var positions = [];
      items.forEach(function (item) {
        var input = item.querySelector('.position-input');
        var pos = input ? parseInt(input.value) || 1 : 1;
        positions.push({ id: item.dataset.id, position: pos });
      });

      var statusEl = document.getElementById('reorder-status');
      saveBtn.disabled = true;
      saveBtn.textContent = 'Saving...';

      var csrfToken = document.querySelector('meta[name="csrf-token"]');
      var token = csrfToken ? csrfToken.getAttribute('content') : '';

      fetch('/channels/update_positions', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': token
        },
        body: JSON.stringify({ positions: positions })
      })
        .then(function (response) { return response.json(); })
        .then(function (data) {
          if (data.success) {
            statusEl.innerHTML = '<span class="text-success"><i class="fa-solid fa-check"></i> Order saved!</span>';
            setTimeout(function () { window.location.reload(); }, 800);
          } else {
            statusEl.innerHTML = '<span class="text-danger"><i class="fa-solid fa-xmark"></i> Failed to save</span>';
            saveBtn.disabled = false;
            saveBtn.textContent = 'Save Order';
          }
        })
        .catch(function () {
          statusEl.innerHTML = '<span class="text-danger"><i class="fa-solid fa-xmark"></i> Network error</span>';
          saveBtn.disabled = false;
          saveBtn.textContent = 'Save Order';
        });
    });
  }
});
