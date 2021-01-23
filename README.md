# CrmDataPackager

CrmDataPackager is a PowerShell module with functions for unpacking and packing Dynamics 365 configuration migration data files.

Read [Announcing the CrmDataPackager PowerShell module](https://alanmervitz.com/2020/12/20/announcing-crmdatapackager-powershell-module/) for an overview of this PowerShell module.

## Installation

Open Windows PowerShell and install the module from the [PowerShell Gallery](https://www.powershellgallery.com/packages/CrmDataPackager/).
```PowerShell
Install-Module -Name CrmDataPackager -Scope CurrentUser
```

## Functions

A brief summary of each function is shown below. See the associated documentation for more details.
### [Expand-CrmData](/docs/functions/Expand-CrmData.md)

Extracts a Configuration Migration tool generated zip file and unpacks the .xml files into separate files and folders.

### [Compress-CrmData](/docs/functions/Compress-CrmData.md)

Packs and zips a folder of Configuration Migration tool generated files previously created from `Expand-CrmData`.

## Project Structure

The primary folders in this repository are:

Path | Description
-----|-------------|
[docs/functions](/docs/functions) | Markdown formatted help documention for each function.
[src/CrmDataPackager](/src/CrmDataPackager) | The source code for the PowerShell module, implemented as advanced functions.

## Support

Support is available by [submitting issues](https://github.com/amervitz/CrmDataPackager/issues) to this GitHub project.

## License

This project uses the [MIT license](https://opensource.org/licenses/MIT). See the [LICENSE](LICENSE) file. 

## Contributions

This project accepts community contributions through GitHub, following the [inbound=outbound](https://opensource.guide/legal/#does-my-project-need-an-additional-contributor-agreement) model as described in the [GitHub Terms of Service](https://help.github.com/articles/github-terms-of-service/#6-contributions-under-repository-license):
> Whenever you make a contribution to a repository containing notice of a license, you license your contribution under the same terms, and you agree that you have the right to license your contribution under those terms.

All contributors are collectively named as `CrmDataPackager contributors` in the [LICENSE](LICENSE) file. Individual contributor names are visible in the commit history.

## History

This project's code originated from [Adoxio.Dynamics.DevOps](https://github.com/Adoxio/Adoxio.Dynamics.DevOps).
