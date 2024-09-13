// Function to follow a contributor and update the button
window.followContributor = function(account_id, community_id=null) {
  let queryParams = [];
  if (community_id) queryParams.push(`community_id=${community_id}`);
  
  const queryString = queryParams.length > 0 ? '?' + queryParams.join('&') : '';

  $.ajax({
    url: `/accounts/${account_id}/follow${queryString}`,
    method: 'POST',
    success: function(response) {
      var followBtn = $(`#follow_btn_${account_id}`);
      
      followBtn.text('Unfollow');
      followBtn.removeClass('btn-outline-dark');
      followBtn.addClass('btn-outline-danger');

      followBtn.attr('onclick', `unfollowContributor('${account_id}', '${community_id}')`);
    },
    error: function() {
      console.log('Error occurred while following contributor');
    }
  });
};

// Function to unfollow a contributor and update the button
window.unfollowContributor = function(account_id, community_id=null) {
  let queryParams = [];
  if (community_id) queryParams.push(`community_id=${community_id}`);
  
  const queryString = queryParams.length > 0 ? '?' + queryParams.join('&') : '';

  $.ajax({
    url: `/accounts/${account_id}/unfollow${queryString}`,
    method: 'POST',
    success: function(response) {
      var followBtn = $(`#follow_btn_${account_id}`);
      
      followBtn.text('Follow');
      followBtn.removeClass('btn-outline-danger');
      followBtn.addClass('btn-outline-dark');

      // Update the button's onclick to call followContributor
      followBtn.attr('onclick', `followContributor('${account_id}', '${community_id}')`);
    },
    error: function() {
      console.log('Error occurred while unfollowing contributor');
    }
  });
};

// Function to search for contributors
function searchContributors(query, communityId) {
  if (query.length === 0) {
    clearSearchResults();
    return;
  }

  showLoadingSpinner();

  fetch(`/communities/${communityId}/search_contributor?query=${encodeURIComponent(query)}`)
    .then(response => response.json())
    .then(data => {
      hideLoadingSpinner();
      displaySearchResults(data.accounts);
    })
    .catch(error => {
      hideLoadingSpinner();
      console.log('Error fetching search results:', error);
    });
}

// Function to show the loading spinner and disable background
function showLoadingSpinner() {
  document.getElementById('disabled-overlay').style.display = 'flex';
}

// Function to hide the loading spinner and enable background
function hideLoadingSpinner() {
  document.getElementById('disabled-overlay').style.display = 'none';
}

// Function to display search results in the modal
function displaySearchResults(accounts) {
  const resultsContainer = document.getElementById('search-results');
  resultsContainer.innerHTML = '';

  if (accounts.length === 0) {
    resultsContainer.innerHTML = '<p>No results found.</p>';
    return;
  }
  var communityID = document.getElementById('community_id');
  if(communityID){
    communityID = communityID.value;
  }
  accounts.forEach(account => {
    const resultItem = document.createElement('div');
    resultItem.className = 'list-group-item align-items-center';
    resultItem.innerHTML = `
      <div class="profile-info row">
        <div class="col-auto">
          <img src="/assets/patchwork-logo.svg" alt="${account.username}" class="rounded-circle mr-2" style="width: 70px; height: 70px;">
        </div>
        <div class="col">
          <p class="mb-0">${account.display_name || account.username}</p>
          <small class="text-muted">@${account.username}@${account.domain}</small>
          ${account.note ? `<small class="small">${account.note}</small>` : ''}
        </div>
        <div class="col-auto ml-5 pl-5 mt-5">
          <button class="btn btn-outline-dark follow-button" id="follow_btn_${account.id}" data-account-id="${account.id}" onclick="followContributor('${account.id}', '${communityID}')" style="float: right;">
            Follow
          </button>
        </div>
      </div>
    `;

    resultsContainer.appendChild(resultItem);
  });
}

// Function to clear the search results
function clearSearchResults() {
  const resultsContainer = document.getElementById('search-results');
  resultsContainer.innerHTML = '';
}

// Event listener for the search box
const searchInput = document.getElementById('search-input');
if (searchInput) {
  searchInput.addEventListener('keydown', function(event) {
    const communityId = this.getAttribute('data-communityId');
    if (event.key === 'Enter' || event.keyCode === 13) {
      searchContributors(this.value, communityId);
    }
  });
}
