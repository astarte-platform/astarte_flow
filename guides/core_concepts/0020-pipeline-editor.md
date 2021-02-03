# Pipeline Editor

The Pipeline Editor is a visual tool designed to facilitate the construction of
[Pipelines](0004-pipelines.html). It is integrated in Astarte Dashboard and automatically opens up
when you head to create a new pipeline.

## Overview

In Astarte Dashboard, go to the Pipelines section and head to create a new pipeline. You should now
be able to see the visual editor, below the field to specify the pipeline's name.

The visual editor itself is composed of two parts:

- A sidebar listing all available [Blocks](0003-blocks.html), grouped together by type
- An empty space where you can drag & drop blocks, connecting them together to effectively design a
  pipeline

### Linking blocks together

Each visual block has up to two handles, In and Out, that represent the block's input and output
respectively. You can link two blocks together by dragging a block's Out handle to the other block's
In handle. Once two blocks are linked you should see a persistent line that connects them.

The number of handles a block has depends upon the block's type:

- `Producer` blocks have the Out handle
- `Consumer` blocks have the In handle
- `Producer & Consumer` blocks have both the In and Out handle

Thus, a valid pipeline starts with a Producer block and ends with a Consumer block.

![Pipeline Editor with a graph of linked blocks](assets/images/pipeline-editor-visual-graph.png)

### Block settings

Each visual block might display a Settings icon in case some options are to be defined for the
block. Clicking on the icon will open a form where such options can be specified. You can then click
on the **Apply settings** button to save the configuration and close the form's modal.

![Modal form to edit a block's options](assets/images/pipeline-editor-block-options.png)

### Generating the pipeline's source

Once the blocks are configured and linked together, this visual representation can be transformed
into a proper [Pipeline's source](0010-defining-a-pipeline.html).

At the bottom right corner of the visual editor, the **Generate pipeline source** button serves the
purpose of translating the graph into source code. If the pipeline's graph present no issues, the
visual tool is hidden and you should see a form to complete the pipeline's definition, with the
pipeline's source field already pre-compiled.

![Pipeline definition with source](assets/images/pipeline-editor-pipeline-source.png)

## Limitations

There are some constraints you should be aware of while building pipelines:

- Multiple producer blocks are not supported, i.e. a pipeline must have exactly one initial block
- Each block cannot have more than one Out connection
- There cannot be blocks forming a loop inside a pipeline
- A pipeline cannot be composed of more than 50 blocks

## Known issues

There are currently some issues that you should be aware of while building pipelines.

Regarding a block's options in the visual editor:

- Properties with the shape of map / object are not yet supported. For instance, if you need to
  define HTTP headers, you can first generate the pipeline's source and then modify it by hand to
  add the property with HTTP headers.
- Properties defining a Lua script should be `<textarea>` but they are rendered as
  `<input type="text">`.
- Properties defining a Lua script do not produce a valid definition when generating the pipeline's
  source. You should double check that a Lua script definition starts with `"""` and ends with
  `"""`.

Moreover:

- Validation of a block's options is only done when opening the modal form to configure them. If a
  block have options that can be configured, you should open the block's setting at least once to
  ensure there are no missing options that should be configured.
- When saving a pipeline, only a basic validation is done on its source. If you modify a pipeline's
  source by hand, you should double-check with the documentation to ensure that the source contains
  valid blocks with valid configurations.
