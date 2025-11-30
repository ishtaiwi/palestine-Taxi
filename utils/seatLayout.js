export const normalizeSeatId = (value) => {
  if (!value) return null;
  const trimmed = value.toString().trim().toLowerCase();
  if (trimmed.startsWith('seat_')) {
    return trimmed;
  }
  return `seat_${trimmed}`;
};

const defaultLayoutForSeatCount = (seatnum = 0) => {
  if (seatnum <= 5) {
    return [2, 3];
  }
  if (seatnum <= 8) {
    return [2, 3, 3];
  }
  const remaining = seatnum - 2;
  const rows = [2];
  let seatsLeft = remaining;
  while (seatsLeft > 0) {
    const rowSize = Math.min(4, seatsLeft);
    rows.push(rowSize);
    seatsLeft -= rowSize;
  }
  return rows;
};

export const buildSeatRows = (seatlayout, seatnum = 0) => {
  const layoutParts = (seatlayout || '')
    .split('+')
    .map((part) => parseInt(part.trim(), 10))
    .filter((value) => !Number.isNaN(value) && value > 0);

  const totalFromLayout = layoutParts.reduce((sum, value) => sum + value, 0);
  const rowSizes =
    layoutParts.length > 0 && (seatnum === 0 || totalFromLayout === seatnum)
      ? layoutParts
      : defaultLayoutForSeatCount(seatnum || totalFromLayout);

  const rows = [];
  let counter = 1;
  rowSizes.forEach((size) => {
    const row = [];
    for (let i = 0; i < size; i += 1) {
      row.push(counter);
      counter += 1;
    }
    rows.push(row);
  });

  return rows;
};

