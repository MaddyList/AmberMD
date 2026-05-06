#!/bin/bash

echo "====================================="
echo " Universal MD Analysis Pipeline"
echo "====================================="

# Create results folder
mkdir -p results

# Check required files
if [ ! -f "complex.prmtop" ] || [ ! -f "prod.nc" ]; then
    echo "Error: complex.prmtop or prod.nc missing!"
    exit 1
fi

#############################################
# CPPTRAJ ANALYSIS
#############################################

cat <<EOF > analysis.in
parm complex.prmtop
trajin prod.nc

autoimage

# =========================
# PROTEIN = CA atoms
# LIGAND = rest (excluding water/ions)
# =========================

rms protein_rmsd @CA first out results/protein_rmsd.dat
rms ligand_rmsd !(@CA,WAT,Na+,Cl-) first out results/ligand_rmsd.dat

atomicfluct out results/rmsf.dat @CA byres

radgyr @CA out results/protein_rg.dat
radgyr !(@CA,WAT,Na+,Cl-) out results/ligand_rg.dat

distance dist @CA !(@CA,WAT,Na+,Cl-) out results/distance.dat

hbond HB out results/hbonds.dat avgout results/hbonds_avg.dat \
donormask @CA \
acceptormask !(@CA,WAT,Na+,Cl-)

EOF

echo "Running cpptraj..."
cpptraj -i analysis.in

#############################################
# CONVERT TO CSV
#############################################

echo "Converting .dat to CSV..."

for file in results/*.dat; do
    base=$(basename "$file" .dat)
    awk 'NF>=2 {print $1","$2}' "$file" > "results/${base}.csv"
done

#############################################
# PYTHON PLOTTING (600 DPI)
#############################################

cat <<EOF > plot_all.py
import numpy as np
import matplotlib.pyplot as plt
import os

def plot(file, title, xlabel, ylabel):
    try:
        data = np.loadtxt(file)
        if data.ndim < 2:
            return

        x = data[:,0]
        y = data[:,1]

        plt.figure()
        plt.plot(x, y)
        plt.xlabel(xlabel)
        plt.ylabel(ylabel)
        plt.title(title)
        plt.grid()

        outfile = file.replace(".dat",".png")
        plt.savefig(outfile, dpi=600)
        plt.close()

    except Exception as e:
        print(f"Skipping {file}: {e}")

base = "results/"

plot(base+"protein_rmsd.dat", "Protein RMSD", "Frame", "RMSD (Å)")
plot(base+"ligand_rmsd.dat", "Ligand RMSD", "Frame", "RMSD (Å)")
plot(base+"rmsf.dat", "Protein RMSF", "Residue", "Fluctuation (Å)")
plot(base+"protein_rg.dat", "Protein Radius of Gyration", "Frame", "Rg (Å)")
plot(base+"ligand_rg.dat", "Ligand Radius of Gyration", "Frame", "Rg (Å)")
plot(base+"distance.dat", "Protein-Ligand Distance", "Frame", "Distance (Å)")
plot(base+"hbonds.dat", "Hydrogen Bonds", "Frame", "Number")

print("All plots saved in results/ (600 DPI)")
EOF

echo "Generating plots..."
python plot_all.py

#############################################
# DONE
#############################################

echo "====================================="
echo " Analysis Completed Successfully!"
echo "====================================="

echo "All outputs saved in:"
echo " -> results/"