(() => {
  const head = document.getElementById('table-head');
  const rows = document.getElementsByClassName('table-data');
  const groupHeaders = document.getElementsByClassName('group-header');

  // add time and elapsed columns
  const time = document.createElement('th');
  const elapsed = document.createElement('th');

  time.setAttribute('scope', 'col');
  elapsed.setAttribute('scope', 'col');

  time.appendChild(document.createTextNode('Time'));
  elapsed.appendChild(document.createTextNode('Elapsed'));

  head.appendChild(time);
  head.appendChild(elapsed);

  for (const header of groupHeaders) {
    header.setAttribute('colspan', '4');
  }

  const currentTime = Math.floor(Date.now() / 1000);

  for (const row of rows) {
    const period = parseInt(row.dataset.period);
    const link = row.dataset.link;
    fetch(link)
      .then(resp => resp.json())
      .then(data => {
        const timeString = new Date(data.seconds * 1000)
              .toLocaleString('en-US');

        let elapsedSecs = currentTime - data.seconds;
        let elapsedMins = Math.floor(elapsedSecs / 60);
        let elapsedHrs = Math.floor(elapsedMins / 60);
        let elapsedDays = Math.floor(elapsedHrs / 24);
        elapsedSecs = elapsedSecs % 60;
        elapsedMins = elapsedMins % 60;
        elapsedHrs = elapsedHrs % 24;

        // granularity: minutes
        const elapsedString =
              (((elapsedDays === 0) ? '' : `${elapsedDays} days `) +
               ((elapsedHrs === 0) ? '' : `${elapsedHrs} hours `) +
               `${elapsedMins} mins`);

        const timeCell = document.createElement('td');
        timeCell.appendChild(document.createTextNode(timeString));

        const elapsedCell = document.createElement('td');
        elapsedCell.appendChild(document.createTextNode(elapsedString));

        row.appendChild(timeCell);
        row.appendChild(elapsedCell);

        if (currentTime - data.seconds >= period) {
          row.classList.add('status-bad');
        } else {
          row.classList.add('status-good');
        }
      });
  }
})();
