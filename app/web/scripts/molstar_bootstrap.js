let viewer = null;
let plugin = null;

function sendToDart(chain, residue, eventType) {
    if (window.onMolstarEvent) {
        window.onMolstarEvent(chain, residue, eventType);
    }
}

window.initializeMolstar = async function (pdbId) {
    const container = document.getElementById("molstar-container");
    viewer = await molstar.Viewer.create(container, {
        layoutIsExpanded: true,
        layoutShowControls: false
    });
    plugin = viewer.plugin;

    plugin.behaviors.interaction.click.subscribe(({ current }) => {
        const { StructureElement, StructureProperties } = molstar.lib.structure;

        const seen = new Set();

        StructureElement.Loci.forEachLocation(current.loci, (loc) => {
            const chain = StructureProperties.chain.auth_asym_id(loc);
            const residue = StructureProperties.residue.auth_seq_id(loc);

            const key = `${chain}:${residue}`;
            if (seen.has(key)) return;
            seen.add(key);

            console.log(chain, residue);

            sendToDart(chain, residue, "click");
        });
    });

    console.log("Molstar initialized");
    console.log(`Loading PDB: ${pdbId}`);
    await loadPdb(pdbId);
    console.log("PDB loaded");
};

window.loadPdb = async function (pdb) {
    if (!viewer) return;
    console.log("Loading pdb");
    console.log(`pdb url: ${pdb}`);
    await viewer.loadPdb(pdb);
    console.log("PDB loaded");
};

window.highlightResidue = function (chainId, residueId) {
    if (!viewer) return;

    viewer.structureInteractivity({
        elements: {
            auth_asym_id: chainId,
            auth_seq_id: residueId
        },
        action: "select"
    });
};

window.clearHighlight = function () {
    if (!plugin) return;
    plugin.managers.interactivity.lociSelects.deselectAll();
};