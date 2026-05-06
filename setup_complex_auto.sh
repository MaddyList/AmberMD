#!/bin/bash
# ----------------------------------------------------------
# AmberTools25 Automated Setup Script for Protein-Ligand MD
# ----------------------------------------------------------
# 1. Cleans the protein PDB (removes alternate conformations, fixes H atoms)
# 2. Checks for duplicates/alternate atoms
# 3. Generates ligand parameters (mol2 + frcmod)
# 4. Builds solvated protein-ligand complex with ions
# 5. Outputs prmtop/inpcrd and solvated PDB
# ----------------------------------------------------------

# -----------------------------
# User-editable filenames
# -----------------------------
PROTEIN="protein.pdb"       # Original protein PDB
LIGAND="ligand.mol2"        # Ligand mol2 file
LIGAND_NAME="ligand"        # Prefix for ligand parameter files
BOX_PADDING=10.0             # TIP3P water box padding in Å

# -----------------------------
# Step 1: Clean protein PDB
# -----------------------------
echo "Cleaning protein PDB..."
pdb4amber -i $PROTEIN -o protein_clean.pdb --reduce --dry

# Optional: remove duplicates (if any) using pdb4amber -- only keep first conformation
echo "Removing alternate conformations / duplicates..."
pdb4amber -i protein_clean.pdb -o protein_clean2.pdb --reduce
PROTEIN_CLEAN="protein_clean2.pdb"

# -----------------------------
# Step 2: Generate ligand parameters
# -----------------------------
echo "Generating ligand parameters..."
antechamber -i $LIGAND -fi mol2 -o ${LIGAND_NAME}_ante.mol2 -fo mol2 -c bcc -s 2
parmchk2 -i ${LIGAND_NAME}_ante.mol2 -f mol2 -o ${LIGAND_NAME}.frcmod

# -----------------------------
# Step 3: Create LEaP input script
# -----------------------------
LEAP_SCRIPT="setup_complex.leap"

cat > $LEAP_SCRIPT << EOF
source leaprc.protein.ff14SB
source leaprc.gaff
source leaprc.water.tip3p

# Load cleaned protein
protein = loadpdb $PROTEIN_CLEAN

# Load ligand
loadamberparams ${LIGAND_NAME}.frcmod
ligand = loadmol2 ${LIGAND_NAME}_ante.mol2

# Combine into complex
complex = combine {protein ligand}

# Neutralize system (auto counter ions)
addions complex Cl- 0

# Solvate with TIP3P water box
solvatebox complex TIP3PBOX $BOX_PADDING

# Save topology and coordinates
saveamberparm complex complex.prmtop complex.inpcrd

# Save PDB of solvated system
savepdb complex complex_solvated.pdb

quit
EOF

# Convert to Unix format
dos2unix $LEAP_SCRIPT

# -----------------------------
# Step 4: Run LEaP
# -----------------------------
echo "Running LEaP..."
tleap -f $LEAP_SCRIPT

echo "Setup complete!"
echo "Topology: complex.prmtop"
echo "Coordinates: complex.inpcrd"
echo "Solvated PDB: complex_solvated.pdb"