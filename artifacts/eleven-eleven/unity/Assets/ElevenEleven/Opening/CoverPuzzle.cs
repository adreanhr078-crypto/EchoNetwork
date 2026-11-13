using System;
using System.Collections.Generic;

namespace ElevenEleven.Opening
{
    public sealed class CoverPuzzle
    {
        public const int Columns = 2;
        public const int Rows = 3;
        public const int TileCount = Columns * Rows;

        private static readonly int[] InitialOrder = { 1, 0, 2, 3, 5, 4 };
        private readonly int[] order = (int[])InitialOrder.Clone();
        private readonly Stack<(int First, int Second)> history = new Stack<(int, int)>();

        public int Selected { get; private set; } = -1;
        public bool ReferenceOpen { get; private set; }
        public bool Solved { get; private set; }
        public bool CanUndo => !Solved && history.Count > 0;

        public int PieceAt(int position) => order[position];

        public void Select(int position)
        {
            if (Solved || ReferenceOpen || !IsPosition(position)) return;

            if (Selected < 0)
                Selected = position;
            else if (Selected == position)
                Selected = -1;
            else
                Swap(Selected, position);
        }

        public bool Swap(int first, int second)
        {
            if (Solved || ReferenceOpen || first == second || !IsPosition(first) || !IsPosition(second))
                return false;

            SwapPieces(first, second);
            history.Push((first, second));
            Selected = -1;
            for (var position = 0; position < TileCount; position++)
                if (order[position] != position) return true;

            Solved = true;
            return true;
        }

        public void ToggleReference()
        {
            if (!Solved) ReferenceOpen = !ReferenceOpen;
        }

        public bool Undo()
        {
            if (!CanUndo) return false;

            var change = history.Pop();
            SwapPieces(change.First, change.Second);
            Selected = -1;
            return true;
        }

        public void Reset()
        {
            if (Solved) return;

            Array.Copy(InitialOrder, order, TileCount);
            history.Clear();
            Selected = -1;
            ReferenceOpen = false;
        }

        private static bool IsPosition(int position) => position >= 0 && position < TileCount;

        private void SwapPieces(int first, int second)
        {
            var piece = order[first];
            order[first] = order[second];
            order[second] = piece;
        }
    }
}
