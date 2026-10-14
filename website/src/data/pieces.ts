// Mirrors src/core/piece_defs.gd in the game.
export type PieceKey = 'I' | 'O' | 'T' | 'S' | 'Z' | 'J' | 'L';

export const SHAPES: Record<PieceKey, [number, number][]> = {
  I: [[-1, 0], [0, 0], [1, 0], [2, 0]],
  O: [[0, 0], [1, 0], [0, 1], [1, 1]],
  T: [[-1, 0], [0, 0], [1, 0], [0, 1]],
  S: [[0, 0], [1, 0], [-1, 1], [0, 1]],
  Z: [[-1, 0], [0, 0], [0, 1], [1, 1]],
  J: [[-1, 0], [0, 0], [1, 0], [-1, 1]],
  L: [[-1, 0], [0, 0], [1, 0], [1, 1]],
};

export const COLORS: Record<PieceKey, string> = {
  I: '#4dd0e1', O: '#ffd54f', T: '#ba68c8', S: '#81c784', Z: '#e57373', J: '#64b5f6', L: '#ffb74d',
};

export const KEYS = Object.keys(SHAPES) as PieceKey[];

/** Cells shifted so the bounding box starts at 0,0. */
export function normalized(key: PieceKey) {
  const cells = SHAPES[key];
  const minX = Math.min(...cells.map((c) => c[0]));
  const minY = Math.min(...cells.map((c) => c[1]));
  const out = cells.map(([x, y]) => [x - minX, y - minY] as [number, number]);
  return { cells: out, w: Math.max(...out.map((c) => c[0])) + 1, h: Math.max(...out.map((c) => c[1])) + 1 };
}
