let viewer = null;
let plugin = null;

// Maps 0-based sequential index → { chain, authSeqId }
// Built after each PDB load. Index 0 = ProteinGym position 1.
let residueMapping = [];

// Stored once at init so loadPdb can rebuild the mapping after a reload.
let _gymSequence = null;

// Last mousedown position in CSS pixels, updated before Mol* resolves the click.
let _lastClickX = 0;
let _lastClickY = 0;

const THREE_TO_ONE = {
    ALA:'A', ARG:'R', ASN:'N', ASP:'D', CYS:'C',
    GLN:'Q', GLU:'E', GLY:'G', HIS:'H', ILE:'I',
    LEU:'L', LYS:'K', MET:'M', PHE:'F', PRO:'P',
    SER:'S', THR:'T', TRP:'W', TYR:'Y', VAL:'V',
};

// Orange highlight for mutated residues.
const MUTATION_COLOR = 0xFF6600;
// Stable ref prefix so we can update rather than re-apply overpaint transforms.
const OVERPAINT_REF_PREFIX = '_mut_overpaint_';

// ---------------------------------------------------------------------------
// Dart bridge
// ---------------------------------------------------------------------------

function sendToDart(seqPosition, eventType) {
    if (window.onMolstarEvent) {
        window.onMolstarEvent(seqPosition, eventType, _lastClickX, _lastClickY);
    }
}

// ---------------------------------------------------------------------------
// Initialisation
// ---------------------------------------------------------------------------

window.initializeMolstar = async function (pdbId, gymSequence, bgColor) {
    _gymSequence = gymSequence ?? null;

    const container = document.getElementById("molstar-container");

    // Capture cursor position before Mol* resolves the click asynchronously.
    container.addEventListener('mousedown', (e) => {
        _lastClickX = e.clientX;
        _lastClickY = e.clientY;
    });

    viewer = await molstar.Viewer.create(container, {
        layoutIsExpanded: true,
        layoutShowControls: false
    });
    plugin = viewer.plugin;

    if (bgColor !== undefined) {
        plugin.canvas3d?.setProps({ renderer: { backgroundColor: bgColor } });
    }

    // Click → resolve to sequential position → send to Dart
    plugin.behaviors.interaction.click.subscribe(({ current }) => {
        const { StructureElement, StructureProperties } = molstar.lib.structure;
        const seen = new Set();

        StructureElement.Loci.forEachLocation(current.loci, (loc) => {
            const chain    = StructureProperties.chain.auth_asym_id(loc);
            const authSeqId = StructureProperties.residue.auth_seq_id(loc);
            const key = `${chain}:${authSeqId}`;
            if (seen.has(key)) return;
            seen.add(key);

            const idx = residueMapping.findIndex(
                r => r.chain === chain && r.authSeqId === authSeqId
            );
            if (idx !== -1) {
                const seqPosition = idx + 1; // convert to 1-based
                console.log(`[Mol*] click: chain=${chain} authSeqId=${authSeqId} → seqPosition=${seqPosition}`);
                sendToDart(seqPosition, "click");
            } else {
                console.warn(`[Mol*] clicked residue not in mapping: ${key}`);
            }
        });
    });

    await loadPdb(pdbId);
};

// ---------------------------------------------------------------------------
// Structure loading + mapping
// ---------------------------------------------------------------------------

window.loadPdb = async function (pdbId, gymSequence) {
    if (gymSequence !== undefined) _gymSequence = gymSequence;
    if (!viewer) return;
    await viewer.loadPdb(pdbId);
    buildResidueMapping();
};

function buildResidueMapping() {
    const structure =
        plugin.managers.structure.hierarchy.current.structures[0]?.cell.obj?.data;
    if (!structure) {
        console.error("[Mol*] buildResidueMapping: no structure loaded");
        return;
    }

    const { StructureElement, StructureProperties } = molstar.lib.structure;
    const loc = StructureElement.Location.create(structure);
    const seen = new Set();
    const fullMapping = [];

    for (const unit of structure.units) {
        loc.unit = unit;
        const { elements } = unit;

        for (let i = 0; i < elements.length; i++) {
            loc.element = elements[i];
            const chain     = StructureProperties.chain.auth_asym_id(loc);
            const authSeqId = StructureProperties.residue.auth_seq_id(loc);
            const compId    = StructureProperties.residue.label_comp_id(loc);
            const key = `${chain}:${authSeqId}`;

            if (!seen.has(key)) {
                seen.add(key);
                const aa = THREE_TO_ONE[compId.toUpperCase()] ?? 'X';
                fullMapping.push({ chain, authSeqId, aa });
            }
        }
    }

    if (!_gymSequence) {
        residueMapping = fullMapping;
        console.log(`[Mol*] No ProteinGym sequence provided; using full PDB mapping (${residueMapping.length} residues)`);
        return;
    }

    const pdbSeqString = fullMapping.map(r => r.aa).join('');
    const offset = pdbSeqString.indexOf(_gymSequence);

    if (offset !== -1) {
        residueMapping = fullMapping.slice(offset, offset + _gymSequence.length);
        const first = residueMapping[0];
        const last  = residueMapping[residueMapping.length - 1];
        console.log(
            `[Mol*] ProteinGym sequence aligned at PDB offset ${offset}` +
            ` (${first.chain}:${first.authSeqId} → ${last.chain}:${last.authSeqId})`
        );
    } else {
        console.warn("[Mol*] ProteinGym sequence not found in PDB sequence; falling back to full PDB mapping");
        residueMapping = fullMapping;
    }

    console.log(`[Mol*] Residue mapping built: ${residueMapping.length} entries`);
    console.log("[Mol*] First 5 entries:", residueMapping.slice(0, 5));
}

// ---------------------------------------------------------------------------
// Selection helpers (shared by selectResidue + highlightResidue + overpaint)
// ---------------------------------------------------------------------------

// Build a StructureElement.Loci for one or more { chain, authSeqId } entries
// by directly iterating units — no MolScript dependency.
function buildLociForResidues(resList) {
    const structure =
        plugin.managers.structure.hierarchy.current.structures[0]?.cell.obj?.data;
    if (!structure || resList.length === 0) return null;

    const { StructureElement, StructureProperties } = molstar.lib.structure;
    const loc = StructureElement.Location.create(structure);
    const targetKeys = new Set(resList.map(r => `${r.chain}:${r.authSeqId}`));
    const elems = [];

    for (const unit of structure.units) {
        loc.unit = unit;
        const matchIdx = [];
        for (let i = 0; i < unit.elements.length; i++) {
            loc.element = unit.elements[i];
            const key =
                `${StructureProperties.chain.auth_asym_id(loc)}:${StructureProperties.residue.auth_seq_id(loc)}`;
            if (targetKeys.has(key)) matchIdx.push(i);
        }
        if (matchIdx.length > 0) {
            elems.push({ unit, indices: new Int32Array(matchIdx) });
        }
    }

    return elems.length > 0
        ? { kind: 'element-loci', structure, elements: elems }
        : null;
}

function buildLociForSeqPosition(seqPosition) {
    const res = residueMapping[seqPosition - 1];
    if (!res) {
        console.error(`[Mol*] No mapping for seq position ${seqPosition}`);
        return null;
    }
    return buildLociForResidues([res]);
}

// ---------------------------------------------------------------------------
// Public API called from Dart
// ---------------------------------------------------------------------------

// Select a residue in the 3D view (sequence panel tile tap).
// seqPosition: 1-based ProteinGym index.
window.selectResidue = function (seqPosition) {
    if (!plugin || !residueMapping.length) return;
    const loci = buildLociForSeqPosition(seqPosition);
    if (!loci) return;
    plugin.managers.interactivity.lociSelects.selectOnly({ loci });
    plugin.managers.camera.focusLoci(loci);
};

// Highlight a single residue (used for hover / focus from outside).
window.highlightResidue = function (seqPosition) {
    if (!plugin || !residueMapping.length) return;
    const loci = buildLociForSeqPosition(seqPosition);
    if (!loci) return;
    plugin.managers.structure.focus.setFromLoci(loci);
};

// Apply (or clear) per-residue overpaint for mutated positions.
// Uses stable refs so subsequent calls update the existing transform nodes
// rather than creating new ones.
async function _applyOverpaint(seqPositions) {
    const { OverpaintStructureRepresentation3DFromBundle } =
        molstar.lib.plugin.StateTransforms.Representation;
    const { StructureElement } = molstar.lib.structure;

    const structureRef =
        plugin.managers.structure.hierarchy.current.structures[0];
    if (!structureRef) return;

    let layers = [];
    if (seqPositions.length > 0) {
        const resList = seqPositions.map(p => residueMapping[p - 1]).filter(Boolean);
        const loci = buildLociForResidues(resList);
        if (loci) {
            const bundle = StructureElement.Bundle.fromLoci(loci);
            layers = [{ bundle, color: MUTATION_COLOR, clear: false }];
        }
    }

    try {
        const update = plugin.build();
        let i = 0;
        for (const component of structureRef.components) {
            for (const repr of component.representations) {
                const ref = `${OVERPAINT_REF_PREFIX}${i++}`;
                if (plugin.state.data.cells.has(ref)) {
                    update.to(ref).update(
                        OverpaintStructureRepresentation3DFromBundle,
                        () => ({ layers })
                    );
                } else {
                    update.to(repr.cell).apply(
                        OverpaintStructureRepresentation3DFromBundle,
                        { layers },
                        { ref }
                    );
                }
            }
        }
        await update.commit({ revertOnError: true });
    } catch (e) {
        console.error("[Mol*] _applyOverpaint failed:", e);
    }
}

// Update the visual color of mutated residues.
// positionsJson: JSON-encoded array of 1-based seq positions, e.g. "[23,45]"
window.updateMutationColors = function (positionsJson) {
    if (!plugin || !residueMapping.length) return;
    const seqPositions = JSON.parse(positionsJson);

    // Clear the 3D selection so the overpaint colour is visible and not masked
    // by the blue selection highlight.
    plugin.managers.interactivity.lociSelects.deselectAll();
    plugin.managers.structure.focus.clear();

    const resolved = seqPositions.map(p => {
        const r = residueMapping[p - 1];
        return r ? `${r.chain}:${r.authSeqId}` : `?(${p})`;
    });
    console.log(
        `[Mol*] updateMutationColors — ${seqPositions.length} mutated positions:\n` +
        `  seq positions : [${seqPositions.join(", ")}]\n` +
        `  PDB residues  : [${resolved.join(", ")}]`
    );

    _applyOverpaint(seqPositions);
};

window.clearHighlight = function () {
    if (!plugin) return;
    plugin.managers.interactivity.lociSelects.deselectAll();
    plugin.managers.structure.focus.clear();
    _applyOverpaint([]);
};